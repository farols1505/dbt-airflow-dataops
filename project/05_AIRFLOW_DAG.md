# 05 — AIRFLOW: DAG `dbt_pipeline`

| | |
|---|---|
| **Phần chấm điểm** | Phần 3 — Airflow Orchestration (15đ) |
| **Thời gian** | 3–4 giờ |
| **Điều kiện** | Đã xong [`04`](04_DBT_MODELS_VA_TESTING.md) (model mới đã merge, `dbt build` trên máy OK) |
| **Kết quả** | DAG chạy hằng ngày theo tầng (run → test từng tầng), retry tăng dần, timeout, kiểm tra chất lượng bằng SQL, thông báo Discord; DAG được pytest kiểm tra trong CI |

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Tạo Discord webhook](#bước-1--tạo-discord-webhook)
- [Bước 2 — Cấu trúc DAG](#bước-2--cấu-trúc-dag)
- [Bước 3 — Xử lý lỗi: retry, timeout, thông báo](#bước-3--xử-lý-lỗi-retry-timeout-thông-báo)
- [Bước 4 — Kiểm tra chất lượng dữ liệu trong pipeline](#bước-4--kiểm-tra-chất-lượng-dữ-liệu-trong-pipeline)
- [Bước 5 — Test DAG bằng pytest](#bước-5--test-dag-bằng-pytest)
- [Bước 6 — Chạy thử trên Airflow](#bước-6--chạy-thử-trên-airflow)
- [Bước 7 — Commit và Pull Request](#bước-7--commit-và-pull-request)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Trạng thái | Nội dung | Mục đích |
|---|---|---|---|
| `airflow/dags/dbt_dag.py` | Viết lại | DAG `dbt_pipeline`: 14 task, `@daily`, TaskGroup theo tầng, SQL checks, tham số `target` / `simulate_new_data`, tài liệu `doc_md` | Toàn bộ Phần 3 |
| `airflow/dags/dataops_utils/__init__.py` | Mới | Đánh dấu thư mục là package Python | Cho DAG import được |
| `airflow/dags/dataops_utils/notifications.py` | Mới | `send_discord()` + 3 callback: task lỗi hẳn, task retry, DAG thành công | "Send notifications on failure" |
| `airflow/dags/.airflowignore` | Mới | Bỏ qua thư mục `dataops_utils/` khi quét DAG | Airflow không mất công phân tích file không chứa DAG |
| `tests/conftest.py` | Mới | Thêm `airflow/dags` vào `sys.path` cho pytest | pytest import được `dataops_utils` giống Airflow |
| `tests/test_dag_integrity.py` | Mới | 18 test: import, vòng lặp, lịch chạy, retry/timeout, callback, **thứ tự 12 cặp task**, `--target` | Job `dag-tests` trong CI (đã có từ file 03, giờ mới thực sự chạy) |
| `pyproject.toml` | Sửa | Thêm `[tool.pytest.ini_options] testpaths = ["tests"]` | `pytest` không cần tham số |

**Kế hoạch commit** (nhánh `feature/airflow-dbt-pipeline`):

| # | Commit message |
|---|---|
| 1 | `feat(airflow): add Discord notification callbacks` |
| 2 | `feat(airflow): rewrite DAG as layered dbt pipeline with quality checks` |
| 3 | `test(airflow): add DAG integrity tests` |

---

## Bước 1 — Tạo Discord webhook

1. Mở Discord → tạo server riêng (nút **+** → *Create My Own*), vd. `DataOps Alerts`.
2. Tạo kênh văn bản `#pipeline-alerts`.
3. Chuột phải kênh → **Edit Channel** → **Integrations** → **Webhooks** → **New Webhook** → đặt tên `DataOps` → **Copy Webhook URL**.
4. Dán URL vào `.env`:
   ```bash
   # mở .env bằng VS Code, sửa dòng:
   NOTIFY_WEBHOOK_URL=https://discord.com/api/webhooks/....
   ```
5. Tạo lại container Airflow để nhận biến mới:
   ```bash
   docker compose up -d
   ```
6. Gửi thử từ container Airflow:
   ```bash
   docker compose exec airflow-scheduler python -c "
   import sys; sys.path.insert(0, '/opt/airflow/dags')
   from dataops_utils.notifications import send_discord, GREEN
   print(send_discord('Kiểm tra kết nối', 'Xin chào từ Airflow 👋', GREEN))"
   ```
   In ra `True` và kênh Discord nhận tin nhắn ✅.

> 🔐 URL webhook là **bí mật** (ai có URL đều gửi được tin vào kênh): chỉ để trong `.env` (đã bị Git bỏ qua) và GitHub Secrets (file 06). Không dán vào code, issue, PR.

---

## Bước 2 — Cấu trúc DAG

```
check_sqlserver → dbt_deps → simulate_ingestion → source_freshness
  → [bronze: dbt_run → dbt_test] → [silver: dbt_run → dbt_test] → [gold: dbt_run → dbt_test]
  → [data_quality: business_rule_tests, gold_tables_not_empty, gold_sales_sanity]
  → dbt_docs_generate
```

| Task | Loại | Làm gì |
|---|---|---|
| `check_sqlserver` | `SQLCheckOperator` | `SELECT 1` qua connection `mssql_default` → SQL Server sống mới chạy tiếp |
| `dbt_deps` | `BashOperator` | `dbt deps` |
| `simulate_ingestion` | `BashOperator` | `dbt run-operation simulate_new_data` nếu tham số `simulate_new_data = true` (mặc định); `false` → bỏ qua |
| `source_freshness` | `BashOperator` | `dbt source freshness` (lỗi nếu dữ liệu cũ > 48 giờ) |
| `<tầng>.dbt_run` / `<tầng>.dbt_test` | `BashOperator` trong `TaskGroup` | `dbt run/test --select path:models/<tầng>`; tầng sau chỉ chạy khi test tầng trước pass |
| `data_quality.*` | Bash + 2 `SQLCheckOperator` | Bước 4 |
| `dbt_docs_generate` | `BashOperator` | Sinh lại tài liệu sau mỗi lần chạy |

**Những điểm thiết kế quan trọng:**

| Điểm | Cách làm | Lý do |
|---|---|---|
| Gọi dbt | `docker exec dbt_airflow_project-dbt-1 dbt ...` | Không cài dbt vào image Airflow; tên container cố định nhờ `name:` trong `docker-compose.yml` (file 02) |
| Chọn model | `--select path:models/bronze` (theo **thư mục**) | Thêm/đổi tên model không phải sửa DAG (quyết định D9) |
| Môi trường | `--target {{ params.target or var.value.get('dbt_target', 'dev') }}` | Trigger thủ công chọn được dev/staging/prod; mặc định theo Variable `dbt_target` (khai báo bằng `AIRFLOW_VAR_DBT_TARGET` ở file 02) |
| Lịch | `schedule="@daily"`, `catchup=False`, `max_active_runs=1` | Chạy mỗi ngày; không chạy bù các ngày đã qua; không chạy chồng |
| Tài liệu | `doc_md` cho DAG (docstring đầu file) và từng task | Đọc ngay trên Airflow UI (*DAG Docs*, *Task Instance Details*) |

---

## Bước 3 — Xử lý lỗi: retry, timeout, thông báo

Khai báo trong `default_args`, áp dụng cho **mọi task**:

| Cấu hình | Giá trị | Ý nghĩa |
|---|---|---|
| `retries` | 2 | Lỗi → thử lại tối đa 2 lần |
| `retry_delay` + `retry_exponential_backoff` + `max_retry_delay` | 2 phút, tăng dần, tối đa 10 phút | Lỗi tạm thời (mạng, SQL Server bận) thường tự hết |
| `execution_timeout` | 30 phút / task | Task treo không giữ tài nguyên mãi |
| `dagrun_timeout` | 2 giờ / lần chạy | |
| `on_retry_callback` | `notify_task_retry` → Discord 🟡 | Biết sớm có vấn đề |
| `on_failure_callback` | `notify_task_failure` → Discord 🔴 (kèm lỗi + link log) | Task lỗi **hẳn** sau khi hết retry |
| `on_success_callback` (cấp DAG) | `notify_dag_success` → Discord 🟢 (kèm thời gian chạy) | Cả pipeline xong |

`dataops_utils/notifications.py`: không có `NOTIFY_WEBHOOK_URL` → chỉ ghi log; gửi lỗi (mạng...) → chỉ ghi cảnh báo, **không bao giờ làm task lỗi theo**.

---

## Bước 4 — Kiểm tra chất lượng dữ liệu trong pipeline

Ngoài `dbt test` sau từng tầng, nhóm `data_quality` kiểm tra lần cuối:

| Task | Kiểm tra | Lỗi khi |
|---|---|---|
| `business_rule_tests` | `dbt test --select test_type:singular` (3 test đối soát của file 04) | Doanh thu/số đơn gold lệch silver; khách đã mua thiếu phân khúc |
| `gold_tables_not_empty` | `SQLCheckOperator`: đếm dòng 4 bảng gold | Có bảng = 0 dòng |
| `gold_sales_sanity` | `SQLCheckOperator`: doanh thu > 0, không có ngày ở tương lai, online + offline = tổng đơn | Bất kỳ điều kiện nào sai |

`SQLCheckOperator` chạy câu SQL, lấy **dòng đầu tiên**: mọi giá trị phải "đúng" (khác 0, khác NULL), không thì task lỗi.

---

## Bước 5 — Test DAG bằng pytest

`tests/test_dag_integrity.py` (18 test) được job **`dag-tests`** trong CI chạy trên mọi PR:

| Test | Bắt lỗi gì |
|---|---|
| `test_no_import_errors` | Lỗi cú pháp/import → "Broken DAG" trên Airflow |
| `test_no_cycles` | Phụ thuộc vòng tròn |
| `test_daily_schedule_without_catchup` | Sai lịch chạy |
| `test_every_task_has_retries_and_timeout` | Task thiếu retry/timeout |
| `test_failure_notifications_configured` | Task thiếu callback khi lỗi |
| `test_task_order` (12 trường hợp) | Sai thứ tự: vd. silver chạy trước khi bronze test xong |
| `test_dbt_commands_use_target` | Lệnh dbt quên `--target` |

Kiểm tra nhanh trên máy (dùng Airflow trong container, không cần cài gì thêm):

```bash
docker compose exec airflow-scheduler airflow dags list-import-errors     # "No data found" = không lỗi
docker compose exec airflow-scheduler airflow tasks list dbt_pipeline     # 14 task
```

**Chạy đủ 18 test pytest trên chính Airflow 2.7.1 trong container** (tùy chọn; đã chạy thử: `18 passed`):

```bash
docker compose cp tests/. airflow-scheduler:/tmp/dagtests
docker compose exec -T airflow-scheduler python -m pip install -q --user pytest==7.4.1
docker compose exec -T -w /tmp -e DAG_TESTS_DAGS_FOLDER=/opt/airflow/dags airflow-scheduler python -m pytest dagtests -q
# → 18 passed
docker compose exec -T airflow-scheduler rm -rf /tmp/dagtests          # dọn dẹp (pytest mất khi tạo lại container)
```

`DAG_TESTS_DAGS_FOLDER` chỉ cho test biết thư mục DAG trong container. Sai thư mục → test **báo lỗi ngay** (`Không thấy file DAG`), không "pass nhầm" với một DagBag rỗng.

> CI chạy pytest bên trong image Airflow chính thức `apache/airflow:2.7.1-python3.11` (đúng phiên bản dự án dùng); pytest được cài với `--only-binary :all:` và khóa phiên bản theo constraints của Airflow.

---

## Bước 6 — Chạy thử trên Airflow

### 6.1. Chuẩn bị nhánh

```bash
git switch develop
git pull
git switch -c feature/airflow-dbt-pipeline
```

Airflow đọc DAG trực tiếp từ thư mục `airflow/dags` trên máy, nên DAG mới **đã có** trên Airflow UI.

### 6.2. Chạy bình thường

1. http://localhost:8080 → DAG **`dbt_pipeline`** (tag `dataops`). DAG cũ `dbt_transform` không còn file → biến mất khỏi danh sách (nếu còn hiện, bấm 🗑️ để xóa lịch sử của nó).
2. Bấm vào DAG → tab **Docs** (hoặc phần mô tả ở đầu trang): tài liệu DAG.
3. Gạt công tắc **bật** → ▶ **Trigger DAG**.
4. Tab **Grid**: 14 task chuyển 🟩 lần lượt (khoảng 1–3 phút; lần chạy thử thực tế: ~1 phút). Tab **Graph**: thấy 3 TaskGroup `bronze`, `silver`, `gold` và `data_quality`.
5. Discord nhận 🟢 *"pipeline dbt chạy THÀNH CÔNG"*.

> Vì DAG có `schedule="@daily"`, khi bật công tắc Airflow có thể tự chạy thêm một lần cho ngày hôm qua. Đó là bình thường.

### 6.3. Chạy với tham số

▶ → **Trigger DAG w/ config** → chọn `target = prod` → *Trigger*. Pipeline build vào `prod_bronze/silver/gold` trên máy bạn (task log ghi `--target prod`).

### 6.4. Diễn tập lỗi + retry + thông báo

Cách dễ nhất: tạm dừng container dbt để mọi lệnh `docker exec` lỗi.

```bash
docker compose stop dbt
```

1. Trigger DAG → `dbt_deps` lỗi (`container ... is not running`) → ô 🟧 *up_for_retry*; Discord nhận 🟡 *"đang thử lại"*.
2. **Cứu pipeline:** trong lúc chờ retry (2 phút), khởi động lại dbt:
   ```bash
   docker compose start dbt
   ```
   Lần thử lại thành công → pipeline chạy tiếp → 🟢. Đây chính là tác dụng của retry.
3. **Hoặc** để dbt dừng → sau 2 lần retry task lỗi hẳn 🟥 → Discord 🔴 kèm lỗi và link log; các task sau chuyển *upstream_failed*. Chạy `docker compose start dbt` sau khi diễn tập.

---

## Bước 7 — Commit và Pull Request

```bash
# 1
git add airflow/dags/dataops_utils/ airflow/dags/.airflowignore
git commit -m "feat(airflow): add Discord notification callbacks"

# 2
git add airflow/dags/dbt_dag.py
git commit -m "feat(airflow): rewrite DAG as layered dbt pipeline with quality checks"

# 3
git add tests/ pyproject.toml
git commit -m "test(airflow): add DAG integrity tests"

git push -u origin feature/airflow-dbt-pipeline
gh pr create --base develop \
  --title "feat(airflow): orchestrate dbt layers with retries, quality checks and alerts" \
  --body "DAG dbt_pipeline: chạy theo tầng, retry tăng dần, timeout, SQL checks, thông báo Discord, 18 test pytest."
gh pr checks --watch
```

Job **`dag-tests`** giờ chạy thật: tải image Airflow 2.7.1 (~1 phút) → `18 passed`.

```bash
gh pr merge --squash --delete-branch
git switch develop && git pull
```

---

## Checklist hoàn thành

- [ ] Discord nhận tin nhắn thử từ container Airflow
- [ ] DAG `dbt_pipeline` hiện trên Airflow, không có "Broken DAG"
- [ ] Một lần chạy đủ 14 task 🟩 + Discord 🟢
- [ ] Đã diễn tập lỗi: thấy retry 🟡 (và/hoặc lỗi hẳn 🔴) trên Discord
- [ ] PR có 4 check xanh (`dag-tests`: 18 passed), đã merge

**Đối chiếu đề bài:**

| Yêu cầu | Đáp ứng |
|---|---|
| DAG chạy model đúng thứ tự | bronze → silver → gold, test xen giữa |
| Phụ thuộc giữa task | 14 task, được pytest kiểm tra |
| Lịch daily/hourly | `@daily` |
| Error handling + retry | 2 retry tăng dần, timeout task + DAG |
| Data quality checks trong pipeline | freshness, `dbt test` từng tầng, singular tests, 2 SQL checks |
| Thông báo khi lỗi | Discord (lỗi, retry, thành công) |
| Tài liệu DAG | `doc_md` cho DAG và từng task |

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| *Broken DAG*: `No module named 'dataops_utils'` | Thiếu `__init__.py` hoặc sai thư mục | Kiểm tra `airflow/dags/dataops_utils/__init__.py` tồn tại |
| `check_sqlserver` lỗi `Login failed for user 'dbt_user'` | Connection `mssql_default` lấy mật khẩu từ `.env` lúc tạo container | Sau khi đổi mật khẩu trong `.env`: `docker compose up -d` |
| `check_sqlserver` lỗi `The conn_id mssql_default isn't defined` | Container Airflow tạo trước file 02 | `docker compose up -d --force-recreate airflow-webserver airflow-scheduler` |
| `source_freshness` lỗi `ERROR STALE` | Đã tắt `simulate_new_data` và dữ liệu cũ > 48 giờ | Đúng thiết kế; trigger lại với `simulate_new_data = true` |
| `silver.dbt_run` lỗi `Invalid column name 'modified_at'` | Bảng incremental kiểu cũ ở target đang chạy (vd. lần đầu chạy `prod` trên máy) | `docker compose exec dbt dbt build --full-refresh --target prod --select slvr_sales_orders+` |
| Không nhận tin Discord | Thiếu/sai `NOTIFY_WEBHOOK_URL`, chưa tạo lại container | Sửa `.env` → `docker compose up -d` → gửi thử (Bước 1.6) |
| Gửi thử in `False` kèm `HTTP Error 403/404` | URL webhook sai hoặc webhook đã bị xóa | Tạo webhook mới |
| Task đứng *queued* mãi | DAG đang tắt | Gạt công tắc bật |
| CI `dag-tests` lỗi khi tải image hoặc cài pytest | Mạng/Docker Hub/PyPI chậm | *Re-run failed jobs* |

---

## Tiếp theo

→ **`06_CD_VA_MULTI_ENV.md`**: cấu hình 3 GitHub Environments, người duyệt production, secrets, thông báo deploy (Phần 4B nâng cao + Bonus 4).
