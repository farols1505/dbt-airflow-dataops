"""Kiểm tra DAG Airflow (chạy trong CI, job dag-tests).

Bắt các lỗi phổ biến TRƯỚC khi DAG lên Airflow: lỗi cú pháp/import ("Broken DAG"), sai lịch chạy,
thiếu retry, sai thứ tự tầng bronze → silver → gold, thiếu thông báo lỗi.
"""

import os

import pytest
from airflow.models import DagBag
from airflow.utils.dag_cycle_tester import check_cycle
from conftest import DAGS_FOLDER

DAG_ID = "dbt_pipeline"
DAG_FILE = os.path.join(DAGS_FOLDER, "dbt_dag.py")


@pytest.fixture(scope="session")
def dagbag() -> DagBag:
    # Thư mục sai → DagBag rỗng → mọi test "không lỗi import" sẽ pass sai. Chặn ngay từ đầu.
    assert os.path.isfile(DAG_FILE), f"Không thấy file DAG: {DAG_FILE}"
    return DagBag(dag_folder=DAGS_FOLDER, include_examples=False)


@pytest.fixture(scope="session")
def dag(dagbag):
    assert DAG_ID in dagbag.dags, f"Không tìm thấy DAG {DAG_ID}. Các DAG: {list(dagbag.dags)}"
    return dagbag.dags[DAG_ID]


def test_no_import_errors(dagbag):
    assert dagbag.import_errors == {}, f"DAG lỗi import: {dagbag.import_errors}"


def test_no_cycles(dag):
    check_cycle(dag)


def test_daily_schedule_without_catchup(dag):
    assert dag.schedule_interval == "@daily"
    assert dag.catchup is False
    assert dag.max_active_runs == 1


def test_every_task_has_retries_and_timeout(dag):
    for task in dag.tasks:
        assert task.retries >= 1, f"{task.task_id} chưa có retry"
        assert task.execution_timeout is not None, f"{task.task_id} chưa có timeout"


def test_failure_notifications_configured(dag):
    assert dag.on_success_callback is not None
    for task in dag.tasks:
        assert task.on_failure_callback is not None, f"{task.task_id} thiếu callback khi lỗi"


@pytest.mark.parametrize(
    "task_id, must_run_after",
    [
        ("dbt_deps", "check_sqlserver"),
        ("simulate_ingestion", "dbt_deps"),
        ("source_freshness", "simulate_ingestion"),
        ("bronze.dbt_run", "source_freshness"),
        ("bronze.dbt_test", "bronze.dbt_run"),
        ("silver.dbt_run", "bronze.dbt_test"),
        ("silver.dbt_test", "silver.dbt_run"),
        ("gold.dbt_run", "silver.dbt_test"),
        ("gold.dbt_test", "gold.dbt_run"),
        ("data_quality.business_rule_tests", "gold.dbt_test"),
        ("data_quality.gold_tables_not_empty", "gold.dbt_test"),
        ("dbt_docs_generate", "data_quality.business_rule_tests"),
    ],
)
def test_task_order(dag, task_id, must_run_after):
    task = dag.get_task(task_id)
    assert must_run_after in task.upstream_task_ids, f"{task_id} phải chạy sau {must_run_after}"


def test_dbt_commands_use_target(dag):
    for task in dag.tasks:
        command = getattr(task, "bash_command", None)
        if command and "dbt " in command and "dbt deps" not in command:
            assert "--target" in command, f"{task.task_id} chưa truyền --target"
