"""
### DAG `dbt_pipeline` — pipeline dữ liệu AdventureWorks hằng ngày

Điều phối toàn bộ pipeline dbt theo kiến trúc medallion, **mỗi tầng chạy xong và qua test
mới sang tầng sau**:

```
check_sqlserver → dbt_deps → simulate_ingestion → source_freshness
  → [bronze: run → test] → [silver: run → test] → [gold: run → test]
  → [data_quality: business_rule_tests, gold_tables_not_empty, gold_sales_sanity]
  → dbt_docs_generate
```

| Thành phần | Cấu hình |
|---|---|
| Lịch chạy | Hằng ngày (`@daily`), không chạy bù các ngày đã qua (`catchup=False`) |
| Retry | 2 lần, chờ 2 phút rồi tăng dần (tối đa 10 phút) |
| Timeout | 30 phút / task, 2 giờ / lần chạy |
| Thông báo | Discord khi task lỗi hẳn, khi retry, khi cả DAG thành công |
| Môi trường | `params.target` (khi Trigger thủ công) hoặc Airflow Variable `dbt_target` |

**Tham số khi Trigger thủ công** (nút ▶ → *Trigger DAG w/ config*):
- `target`: `dev` / `staging` / `prod` (để trống = theo Variable `dbt_target`).
- `simulate_new_data`: `true` = mô phỏng một lần nạp dữ liệu mới trước khi kiểm tra freshness.
  Đặt `false` = không nạp dữ liệu mới; nếu 48 giờ qua chưa mô phỏng lần nào, freshness sẽ báo lỗi
  (dữ liệu AdventureWorks cũ từ 2014) → minh họa retry + thông báo lỗi.

dbt chạy trong container `dbt_airflow_project-dbt-1` qua `docker exec`.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.models.param import Param
from airflow.operators.bash import BashOperator
from airflow.providers.common.sql.operators.sql import SQLCheckOperator
from airflow.utils.task_group import TaskGroup
from dataops_utils.notifications import notify_dag_success, notify_task_failure, notify_task_retry

DBT_CONTAINER = "dbt_airflow_project-dbt-1"
MSSQL_CONN_ID = (
    "mssql_default"  # khai báo qua biến AIRFLOW_CONN_MSSQL_DEFAULT trong docker-compose.yml
)
LAYERS = ("bronze", "silver", "gold")

# Jinja: môi trường của lần chạy = params.target (nếu có),
# ngược lại Airflow Variable dbt_target, mặc định dev
TARGET = "{{ params.target or var.value.get('dbt_target', 'dev') }}"


def dbt(command: str) -> str:
    """Lệnh bash chạy `dbt <command>` trong container dbt, với target của lần chạy."""
    return f"docker exec {DBT_CONTAINER} dbt {command} --target " + TARGET


default_args = {
    "owner": "dataops",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=10),
    "execution_timeout": timedelta(minutes=30),
    "on_failure_callback": notify_task_failure,
    "on_retry_callback": notify_task_retry,
}

with DAG(
    dag_id="dbt_pipeline",
    description="Pipeline dbt hằng ngày: freshness → bronze → silver → gold → kiểm tra chất lượng",
    doc_md=__doc__,
    schedule="@daily",
    start_date=datetime(2026, 11, 1),
    catchup=False,
    max_active_runs=1,
    dagrun_timeout=timedelta(hours=2),
    default_args=default_args,
    on_success_callback=notify_dag_success,
    params={
        "target": Param(
            None,
            type=["null", "string"],
            enum=[None, "dev", "staging", "prod"],
            description="Môi trường dbt. Để trống = theo Airflow Variable dbt_target.",
        ),
        "simulate_new_data": Param(
            True,
            type="boolean",
            description="Mô phỏng một lần nạp dữ liệu mới trước khi kiểm tra freshness.",
        ),
    },
    tags=["dbt", "sqlserver", "dataops"],
) as dag:

    check_sqlserver = SQLCheckOperator(
        task_id="check_sqlserver",
        conn_id=MSSQL_CONN_ID,
        sql="SELECT 1",
        doc_md="Kiểm tra SQL Server kết nối được trước khi chạy pipeline.",
    )

    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"docker exec {DBT_CONTAINER} dbt deps",
        doc_md="Cài các dbt package (dbt_utils).",
    )

    simulate_ingestion = BashOperator(
        task_id="simulate_ingestion",
        bash_command=(
            "{% if params.simulate_new_data %}"
            + dbt("run-operation simulate_new_data")
            + "{% else %}"
            + "echo 'Bỏ qua mô phỏng dữ liệu mới (simulate_new_data = false)'"
            + "{% endif %}"
        ),
        doc_md=(
            "Mô phỏng bước nạp dữ liệu từ hệ thống nguồn (AdventureWorks là dữ liệu tĩnh): "
            "cập nhật ModifiedDate của một số bản ghi bằng macro dbt `simulate_new_data`."
        ),
    )

    source_freshness = BashOperator(
        task_id="source_freshness",
        bash_command=dbt("source freshness"),
        doc_md="Kiểm tra dữ liệu nguồn còn tươi (cảnh báo > 24 giờ, lỗi > 48 giờ).",
    )

    check_sqlserver >> dbt_deps >> simulate_ingestion >> source_freshness

    # Mỗi tầng: dbt run → dbt test. Tầng sau chỉ chạy khi tầng trước đã qua test.
    previous = source_freshness
    for layer in LAYERS:
        with TaskGroup(group_id=layer, tooltip=f"Tầng {layer}: run rồi test") as layer_group:
            run = BashOperator(
                task_id="dbt_run",
                bash_command=dbt(f"run --select path:models/{layer}"),
                doc_md=f"Build các model trong models/{layer}.",
            )
            # --indirect-selection buildable: chỉ lấy test có MỌI model cha đã được build tới tầng
            # này. Mặc định (eager) sẽ kéo cả test so sánh gold↔silver vào bước silver.dbt_test,
            # lúc bảng gold chưa tồn tại (target mới, vd. prod lần đầu) → "Invalid object name".
            # Nhờ vậy mỗi test chạy đúng một lần: bronze 75 + silver 32 + gold 36 = 143.
            test = BashOperator(
                task_id="dbt_test",
                bash_command=dbt(
                    f"test --select path:models/{layer} --indirect-selection buildable"
                ),
                doc_md=f"Chạy các test gắn với models/{layer} (chỉ test mà model cha đã build).",
            )
            run >> test
        previous >> layer_group
        previous = layer_group

    with TaskGroup(
        group_id="data_quality", tooltip="Kiểm tra chất lượng dữ liệu cuối pipeline"
    ) as dq:
        BashOperator(
            task_id="business_rule_tests",
            bash_command=dbt("test --select test_type:singular"),
            doc_md="Các test nghiệp vụ (đối soát doanh thu gold/silver, số đơn, phân khúc RFM).",
        )
        SQLCheckOperator(
            task_id="gold_tables_not_empty",
            conn_id=MSSQL_CONN_ID,
            sql=f"""
                SELECT
                    (SELECT COUNT(*) FROM [{TARGET}_gold].[gld_sales_summary]) AS sales_rows,
                    (SELECT COUNT(*) FROM [{TARGET}_gold].[gld_customer_metrics]) AS customer_rows,
                    (SELECT COUNT(*) FROM [{TARGET}_gold].[gld_product_performance])
                        AS product_rows,
                    (SELECT COUNT(*) FROM [{TARGET}_gold].[gld_customer_segments]) AS segment_rows
            """,
            doc_md="Mọi bảng gold phải có dữ liệu (mỗi giá trị trả về phải > 0).",
        )
        SQLCheckOperator(
            task_id="gold_sales_sanity",
            conn_id=MSSQL_CONN_ID,
            sql=f"""
                SELECT
                    CASE WHEN MIN(total_revenue) > 0 THEN 1 ELSE 0 END AS revenue_positive,
                    CASE WHEN MAX(order_date) <= CAST(GETDATE() AS date) THEN 1 ELSE 0 END
                        AS no_future_dates,
                    CASE WHEN SUM(online_orders + offline_orders) = SUM(total_orders)
                        THEN 1 ELSE 0 END
                        AS channels_consistent
                FROM [{TARGET}_gold].[gld_sales_summary]
            """,
            doc_md="Doanh thu dương, không có ngày ở tương lai, số đơn theo kênh khớp tổng số đơn.",
        )

    dbt_docs_generate = BashOperator(
        task_id="dbt_docs_generate",
        bash_command=dbt("docs generate"),
        doc_md="Sinh lại tài liệu dbt + lineage sau mỗi lần chạy.",
    )

    previous >> dq >> dbt_docs_generate
