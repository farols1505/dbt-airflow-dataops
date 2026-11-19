# Giám sát pipeline

## 1. Grafana (Bonus 1)

### Khởi động

```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d grafana
```

Mở http://localhost:3000 → đăng nhập `admin` / `GRAFANA_ADMIN_PASSWORD` (mặc định `admin`). Dashboard **DataOps Pipeline — dbt + Airflow** là trang chủ.

> Mẹo: thêm dòng `COMPOSE_FILE=docker-compose.yml:docker-compose.monitoring.yml` vào `.env` để mọi lệnh `docker compose ...` tự gồm Grafana.

### Cấu hình bằng code (provisioning)

| File | Nội dung |
|---|---|
| `docker-compose.monitoring.yml` | Container Grafana (image ghim phiên bản `13.2.4`), cổng `127.0.0.1:3000`, truyền mật khẩu từ `.env` |
| `monitoring/grafana/provisioning/datasources/datasources.yml` | 2 datasource: **Airflow Metadata (PostgreSQL)** và **AdventureWorks (SQL Server)** |
| `monitoring/grafana/provisioning/dashboards/dashboards.yml` | Nạp mọi dashboard JSON trong `monitoring/grafana/dashboards/` |
| `monitoring/grafana/dashboards/dataops-pipeline.json` | Dashboard chính |

Sửa dashboard: chỉnh file JSON → `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml restart grafana`.

### Các panel

| Nhóm | Panel | Nguồn | Câu hỏi trả lời |
|---|---|---|---|
| Pipeline | Tỉ lệ chạy thành công (30 ngày) | PostgreSQL `dag_run` | Pipeline có ổn định không? (đỏ < 80%, vàng < 95%) |
| Pipeline | Số lần chạy, trạng thái & thời gian lần gần nhất | `dag_run` | Lần chạy gần nhất ra sao? |
| Pipeline | Thời gian chạy theo thời gian | `dag_run` | Pipeline có chậm dần không? |
| Pipeline | Thời gian trung bình theo task | `task_instance` | Task nào tốn thời gian nhất? |
| Pipeline | Các lần task lỗi gần đây (kể cả lỗi rồi retry thành công) | `task_fail` | Lỗi gì, khi nào? Retry có cứu được không? |
| Dữ liệu | Độ tươi dữ liệu nguồn (giờ) | SQL Server `Sales.SalesOrderHeader` | Dữ liệu có bị cũ? (ngưỡng khớp source freshness 24h/48h) |
| Dữ liệu | Số dòng các bảng silver/gold | SQL Server `sys.partitions` | Bảng có rỗng/bất thường? |
| Dữ liệu | Phân khúc khách hàng (RFM) | `<env>_gold.gld_customer_segments` | Chỉ số kinh doanh |
| Dữ liệu | Doanh thu theo tháng | `<env>_gold.gld_sales_summary` | Chỉ số kinh doanh |

Biến **Môi trường** (đầu dashboard) chọn `dev` / `staging` / `prod` cho nhóm Dữ liệu.

## 2. Thông báo Discord

| Nguồn | Khi nào | Màu |
|---|---|---|
| Airflow — `on_failure_callback` | Task lỗi hẳn (hết retry) | 🔴 |
| Airflow — `on_retry_callback` | Task lỗi, đang thử lại | 🟡 |
| Airflow — `on_success_callback` (DAG) | Cả pipeline thành công | 🟢 |
| GitHub Actions — `scripts/ci/notify.py` | Mỗi lần deploy / rollback (thành công, lỗi, đã rollback) | 🟢 / 🔴 |

Cấu hình: `NOTIFY_WEBHOOK_URL` trong `.env` (Airflow) và GitHub Secret `NOTIFY_WEBHOOK_URL` (Actions).

## 3. Giám sát deployment

Xem [`DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md#5-giám-sát-deployment).
