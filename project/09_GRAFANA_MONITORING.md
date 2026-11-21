# 09 — GRAFANA: DASHBOARD GIÁM SÁT (Bonus 1)

| | |
|---|---|
| **Phần chấm điểm** | Bonus 1 — Monitoring Dashboard (+5đ) |
| **Thời gian** | 1–2 giờ |
| **Điều kiện** | Đã xong [`08`](08_TAI_LIEU_VA_DEMO.md); DAG `dbt_pipeline` đã chạy vài lần (để có số liệu) |
| **Kết quả** | Grafana chạy ở http://localhost:3000, datasource + dashboard **dạng code**, giám sát cả pipeline Airflow lẫn dữ liệu |

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Cách Grafana được cấu hình bằng code](#bước-1--cách-grafana-được-cấu-hình-bằng-code)
- [Bước 2 — Khởi động Grafana](#bước-2--khởi-động-grafana)
- [Bước 3 — Kiểm tra datasource](#bước-3--kiểm-tra-datasource)
- [Bước 4 — Đọc dashboard](#bước-4--đọc-dashboard)
- [Bước 5 — Tạo số liệu để dashboard sinh động](#bước-5--tạo-số-liệu-để-dashboard-sinh-động)
- [Bước 6 — Commit và Pull Request](#bước-6--commit-và-pull-request)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Nội dung | Mục đích |
|---|---|---|
| `docker-compose.monitoring.yml` | Service `grafana` (image ghim `grafana/grafana:13.2.4`), cổng `127.0.0.1:3000`, đọc mật khẩu từ `.env`, gắn 2 thư mục provisioning, volume `grafana_data` | **File riêng**: không sửa `docker-compose.yml` gốc (đề bài: không cần sửa hạ tầng; tool thêm phải tách biệt và có tài liệu) |
| `monitoring/grafana/provisioning/datasources/datasources.yml` | 2 datasource: `Airflow Metadata (PostgreSQL)` (uid `airflow-postgres`), `AdventureWorks (SQL Server)` (uid `adventureworks-mssql`); mật khẩu dạng `$POSTGRES_PASSWORD`, `$DBT_ENV_SECRET_PASSWORD` | Grafana tự tạo datasource khi khởi động, không lưu mật khẩu trong file |
| `monitoring/grafana/provisioning/dashboards/dashboards.yml` | Provider: nạp mọi file JSON trong `/var/lib/grafana/dashboards` vào thư mục `DataOps` | Dashboard as code |
| `monitoring/grafana/dashboards/dataops-pipeline.json` | Dashboard 11 panel (+2 hàng tiêu đề), biến `env` (dev/staging/prod) | Nội dung giám sát |
| `docs/MONITORING.md` | Cách chạy, danh sách panel và câu hỏi mỗi panel trả lời, bảng thông báo Discord | Tài liệu |
| `.env.example` | Biến `GRAFANA_ADMIN_PASSWORD` (đã commit ở file 03, Bước 0) | |

**Kế hoạch commit** (nhánh `feature/grafana-monitoring`):

| # | Commit message |
|---|---|
| 1 | `feat(monitoring): add Grafana with provisioned datasources` |
| 2 | `feat(monitoring): add pipeline and data dashboard` |
| 3 | `docs: add monitoring guide` |

---

## Bước 1 — Cách Grafana được cấu hình bằng code

```
docker-compose.monitoring.yml
  └─ grafana container
       ├─ /etc/grafana/provisioning/datasources/datasources.yml   ← tạo 2 datasource
       ├─ /etc/grafana/provisioning/dashboards/dashboards.yml     ← "nạp dashboard từ thư mục X"
       └─ /var/lib/grafana/dashboards/dataops-pipeline.json       ← dashboard
```

- **Không bấm tay trên giao diện:** xóa container tạo lại vẫn y nguyên; mọi thay đổi đi qua Git như code.
- Datasource Postgres đọc **metadata của Airflow** (bảng `dag_run`, `task_instance`): lịch sử mọi lần chạy DAG, không cần Airflow ghi thêm gì.
- Datasource SQL Server đọc dữ liệu bằng tài khoản `dbt_user`.
- `allowUiUpdates: false`, `editable: false`: sửa trên giao diện không lưu được, phải sửa file. Đây là cố ý.

---

## Bước 2 — Khởi động Grafana

1. Thêm mật khẩu Grafana vào `.env` (nếu `.env` của bạn tạo trước file 03 thì chưa có dòng này):
   ```bash
   grep -q '^GRAFANA_ADMIN_PASSWORD=' .env || echo "GRAFANA_ADMIN_PASSWORD=Grafana$(openssl rand -hex 4)" >> .env
   grep '^GRAFANA_ADMIN_PASSWORD=' .env
   ```
2. Khởi động (luôn kèm file gốc):
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d grafana
   docker compose -f docker-compose.yml -f docker-compose.monitoring.yml ps grafana     # Up
   docker compose -f docker-compose.yml -f docker-compose.monitoring.yml logs grafana | grep -iE "provision|error" | tail
   ```
3. Mở http://localhost:3000 → đăng nhập `admin` / mật khẩu ở trên. Trang chủ là dashboard **DataOps Pipeline — dbt + Airflow**.

> **Mẹo:** thêm dòng `COMPOSE_FILE=docker-compose.yml:docker-compose.monitoring.yml` vào `.env` → các lệnh `docker compose ...` tự gồm Grafana, không phải gõ `-f` nữa.

---

## Bước 3 — Kiểm tra datasource

**Connections → Data sources**:
- `Airflow Metadata (PostgreSQL)` → **Test** → *Database Connection OK*.
- `AdventureWorks (SQL Server)` → **Test** → *Database Connection OK*.

---

## Bước 4 — Đọc dashboard

| Hàng | Panel | Câu hỏi trả lời |
|---|---|---|
| **Pipeline Airflow** | Tỉ lệ chạy thành công (30 ngày) | Pipeline có ổn định không? (đỏ < 80%, vàng < 95%, xanh ≥ 95%) |
| | Số lần chạy (30 ngày) | Pipeline có chạy đều không? |
| | Trạng thái lần chạy gần nhất | Lần gần nhất thành công hay thất bại? |
| | Thời gian lần chạy gần nhất | |
| | Thời gian chạy theo thời gian | Pipeline có chậm dần không? |
| | Thời gian trung bình theo task | Task nào là "nút cổ chai"? |
| | Các lần task lỗi gần đây | Lỗi gì, lúc nào? (đọc bảng `task_fail`: thấy cả lần lỗi mà retry đã cứu được) |
| **Dữ liệu — `$env`** | Độ tươi dữ liệu nguồn (giờ) | Dữ liệu có bị cũ? (ngưỡng 24h/48h khớp freshness của dbt) |
| | Số dòng các bảng silver / gold | Bảng nào rỗng/bất thường? |
| | Phân khúc khách hàng (RFM) | Chỉ số kinh doanh từ gold |
| | Doanh thu theo tháng | Chỉ số kinh doanh từ gold |

Đầu dashboard có ô **Môi trường** (`dev` / `staging` / `prod`): đổi để xem dữ liệu của schema tương ứng **trên máy bạn** (`prod` chỉ có dữ liệu nếu đã trigger DAG với `target = prod` ở file 05).

---

## Bước 5 — Tạo số liệu để dashboard sinh động

- Trigger DAG `dbt_pipeline` thêm vài lần (có thể thay `target`).
- Diễn tập lỗi như file 05, Bước 6.4 (`docker compose stop dbt` → trigger → `docker compose start dbt`) → panel "Các lần task lỗi gần đây" có dữ liệu, tỉ lệ thành công thay đổi.
- Chụp ảnh dashboard (lưu `docs/images/grafana-dashboard.png` nếu muốn đưa vào tài liệu; khi đó thêm dòng `![Grafana](images/grafana-dashboard.png)` vào `docs/MONITORING.md`).

---

## Bước 6 — Commit và Pull Request

```bash
git switch develop && git pull
git switch -c feature/grafana-monitoring

git add docker-compose.monitoring.yml monitoring/grafana/provisioning/
git commit -m "feat(monitoring): add Grafana with provisioned datasources"

git add monitoring/grafana/dashboards/
git commit -m "feat(monitoring): add pipeline and data dashboard"

git add docs/MONITORING.md          # (+ docs/images/grafana-dashboard.png nếu có)
git commit -m "docs: add monitoring guide"

git push -u origin feature/grafana-monitoring
gh pr create --base develop --title "feat(monitoring): add Grafana dashboard for pipeline and data" \
  --body "Grafana (file compose riêng), datasource + dashboard dạng code, tài liệu giám sát."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --squash --delete-branch && git switch develop && git pull
```

---

## Checklist hoàn thành

- [ ] Grafana chạy, đăng nhập được, 2 datasource *Test* OK
- [ ] Dashboard hiển thị số liệu ở cả 2 hàng (Pipeline, Dữ liệu)
- [ ] Đổi biến **Môi trường** thấy dữ liệu thay đổi
- [ ] PR đã merge

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `service "grafana" depends on undefined service "postgres"` | Chạy riêng file monitoring | Luôn kèm `-f docker-compose.yml -f docker-compose.monitoring.yml` |
| `required variable POSTGRES_PASSWORD is missing` | Thiếu `.env` | Chạy ở thư mục dự án có `.env` |
| Không vào được http://localhost:3000 | Container chưa chạy / cổng 3000 bị chiếm | `docker compose ... ps grafana`, `logs grafana`; tắt chương trình dùng cổng 3000 |
| Datasource Postgres *Test* lỗi `password authentication failed` | `POSTGRES_PASSWORD` trong `.env` khác mật khẩu volume Postgres | Dùng đúng mật khẩu đã dùng khi tạo volume (file 02, Bước 7.2) |
| Datasource SQL Server *Test* lỗi `Login failed` | Mật khẩu dbt đổi sau khi tạo container Grafana | `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --force-recreate grafana` |
| Panel hàng Pipeline *No data* | DAG chưa chạy, hoặc chưa chạy trong khoảng thời gian đang xem | Trigger DAG; đổi khung thời gian góc phải trên thành *Last 30 days* |
| Panel hàng Dữ liệu lỗi `Invalid object name 'prod_gold...'` | Chưa build môi trường đó trên máy | Chọn `dev`, hoặc trigger DAG với `target = prod` |
| Panel báo lỗi cú pháp SQL | Phiên bản Grafana khác cách hiểu một tùy chọn | Sửa câu SQL / tùy chọn trong `dataops-pipeline.json` → `docker compose ... restart grafana` |
| Sửa dashboard trên giao diện không lưu được | `allowUiUpdates: false` (cố ý) | Sửa file JSON. Muốn thiết kế bằng giao diện: *Save as* bản sao → *Export → JSON* → dán vào file |

---

## Tiếp theo

→ **`10_LINEAGE_GITHUB_PAGES.md`** (Bonus 2).
