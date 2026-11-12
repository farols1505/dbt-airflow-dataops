# 00 — TỔNG QUAN DỰ ÁN DATAOPS
## dbt + Apache Airflow + SQL Server + GitHub Actions

> **Tài liệu dành cho cả nhóm (3 thành viên).** Mỗi người đọc hết file này trước khi bắt đầu code.
> File này trả lời 3 câu hỏi: **(1) Phải làm những gì? (2) Làm theo cách nào? (3) Ai làm phần nào?**
> Hướng dẫn chi tiết từng bước nằm ở các file `01_...`, `02_...` (xem [mục 12](#12-danh-sách-tài-liệu-hướng-dẫn-tiếp-theo)).
>
> Đề bài gốc: [`4. DATAOPS_PROJECT_REQUIREMENTS.md`](../4.%20DATAOPS_PROJECT_REQUIREMENTS.md)

---

## Mục lục

1. [Dự án này là gì?](#1-dự-án-này-là-gì)
2. [Mục tiêu điểm của nhóm](#2-mục-tiêu-điểm-của-nhóm)
3. [Kiến trúc sau khi hoàn thành](#3-kiến-trúc-sau-khi-hoàn-thành)
4. [Hiện trạng repo: cái đã có và cái cần sửa](#4-hiện-trạng-repo-cái-đã-có-và-cái-cần-sửa)
5. [Các quyết định kỹ thuật đã chốt](#5-các-quyết-định-kỹ-thuật-đã-chốt)
6. [Danh sách công việc chi tiết (theo phần chấm điểm)](#6-danh-sách-công-việc-chi-tiết-theo-phần-chấm-điểm)
7. [Cấu trúc thư mục mục tiêu](#7-cấu-trúc-thư-mục-mục-tiêu)
8. [Quy ước làm việc nhóm](#8-quy-ước-làm-việc-nhóm)
9. [Phân công 3 thành viên](#9-phân-công-3-thành-viên)
10. [Kế hoạch 3 tuần](#10-kế-hoạch-3-tuần)
11. [Checklist nộp bài + rủi ro cần lưu ý](#11-checklist-nộp-bài--rủi-ro-cần-lưu-ý)
12. [Danh sách tài liệu hướng dẫn tiếp theo](#12-danh-sách-tài-liệu-hướng-dẫn-tiếp-theo)

---

## 1. Dự án này là gì?

Nhóm xây dựng một **pipeline dữ liệu tự động** theo tinh thần **DataOps** (áp dụng DevOps vào dữ liệu):

- **Dữ liệu nguồn:** database mẫu **AdventureWorks2014** (công ty bán xe đạp) chạy trên **SQL Server**.
- **Biến đổi dữ liệu:** dùng **dbt**, chia 3 tầng:
  - **Bronze**: lấy dữ liệu thô, làm sạch nhẹ (đổi tên cột, ép kiểu).
  - **Silver**: join nhiều bảng bronze, áp dụng logic nghiệp vụ.
  - **Gold**: bảng tổng hợp/chỉ số kinh doanh, sẵn sàng cho báo cáo.
- **Điều phối:** **Airflow** chạy dbt theo lịch (hằng ngày), tự retry khi lỗi, gửi cảnh báo khi thất bại.
- **Tự động hóa:** **GitHub Actions**
  - **CI**: mỗi Pull Request → tự động lint code, compile và test dbt.
  - **CD**: mỗi lần merge vào `develop`/`main` → tự động chạy `dbt deps → dbt run → dbt test`, có môi trường dev/staging/prod, thông báo, rollback.
- **Giám sát:** dashboard **Grafana** theo dõi pipeline; **lineage** (sơ đồ luồng dữ liệu) công khai trên GitHub Pages.

**Thông tin đề bài:** nhóm 3 người · 3 tuần · 100 điểm · **qua môn = 60 điểm (MVP)** · bonus tối đa +15.

> ⚠️ Docker đã được cung cấp sẵn và **không được chấm điểm**. Điểm nằm ở những gì nhóm xây **trên** Docker.

---

## 2. Mục tiêu điểm của nhóm

| Phần | Điểm tối đa | Mục tiêu nhóm | Người phụ trách chính |
|---|---|---|---|
| 1. dbt Data Models | 25 | 25 | Thành viên B |
| 2. Automated Testing | 20 | 20 | Thành viên B |
| 3. Airflow Orchestration | 15 | 15 | Thành viên C |
| 4. CI/CD & Deployment Automation | **35** | 35 | **Trưởng nhóm (bạn)** |
| 5. Documentation & Presentation | 5 | 5 | Thành viên C (+ cả nhóm) |
| **Bonus 1** – Monitoring Dashboard (Grafana) | +5 | +5 | Thành viên C |
| **Bonus 2** – Data Lineage Visualization | +5 | +5 | Thành viên B |
| **Bonus 4** – Multi-environment (dev/staging/prod) | +5 | +5 | **Trưởng nhóm (bạn)** |

> Nhóm **không làm slide và video demo** (giáo viên không yêu cầu). Buổi thuyết trình là **demo trực tiếp** trên hệ thống thật.

> **Nguyên tắc vàng:** Bonus **không bù** cho phần bắt buộc bị thiếu. Thứ tự ưu tiên luôn là:
> **MVP 60 điểm → đủ 100 điểm → bonus.**

---

## 3. Kiến trúc sau khi hoàn thành

```
                         ┌──────────────────────── GitHub ─────────────────────────┐
  Developer              │                                                          │
  (feature branch) ──PR──►  CI (ci.yml, pr-validation.yml)                          │
                         │   • flake8 + black (Python)  • sqlfluff (SQL)            │
                         │   • dbt compile + dbt build trên SQL Server tạm          │
                         │   • kiểm tra tiêu đề PR, kích thước file, conflict       │
                         │                                                          │
                         │  merge → develop ──► CD: deploy DEV                      │
                         │  merge → main    ──► CD: deploy STAGING ──(duyệt)──► PROD│
                         │       • pre-check → backup → dbt run/test → health check │
                         │       • thông báo Discord/Slack • tag phiên bản • rollback│
                         │                                                          │
                         │  GitHub Pages: dbt docs + lineage graph (Bonus 2)        │
                         └──────────────────────────────────────────────────────────┘

  ┌──────────────────────── Docker Compose (máy local) ─────────────────────────────┐
  │                                                                                  │
  │  SQL Server (AdventureWorks2014)                                                 │
  │     Sales / Production / Person  ──dbt──►  <env>_bronze ─► <env>_silver ─► <env>_gold
  │                                                                                  │
  │  Airflow (webserver + scheduler)  ── DAG dbt_pipeline (hằng ngày) ──► dbt        │
  │     freshness → bronze → silver → gold → kiểm tra chất lượng → thông báo         │
  │                                                                                  │
  │  PostgreSQL (metadata Airflow) ◄── Grafana (Bonus 1) đọc lịch sử chạy DAG        │
  └──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Hiện trạng repo: cái đã có và cái cần sửa

Repo được giáo viên cung cấp đã có sẵn một phần. **Không phải xây từ con số 0**, nhưng có nhiều điểm phải sửa để đạt điểm tối đa.

### 4.1. Cái đã có

| Thành phần | Hiện trạng |
|---|---|
| Docker (5 container) | ✅ Chạy được (đã build trên máy trưởng nhóm) |
| Bronze | 4 model: `brnz_customers`, `brnz_products`, `brnz_sales_orders`, `brnz_example` |
| Silver | 3 model: `slvr_customers`, `slvr_products`, `slvr_sales_orders` |
| Gold | 3 model: `gld_customer_metrics`, `gld_product_performance`, `gld_sales_summary` |
| Test | Chỉ có `not_null`, `unique`, `dbt_utils.unique_combination_of_columns` |
| Airflow | 1 DAG `dbt_transform`: `dbt run >> dbt test`, chạy **mỗi 5 phút** |
| Git / CI/CD / tài liệu | ❌ Chưa có gì |

### 4.2. Vấn đề cần sửa (ảnh hưởng trực tiếp tới điểm)

| # | Vấn đề | Vì sao mất điểm | Cách sửa |
|---|---|---|---|
| 1 | Model bronze đang **join nhiều bảng** (vd. `brnz_customers` join `Person`) | Tiêu chí *"Proper layering and separation of concerns"* (8đ): bronze phải 1-1 với bảng nguồn, join là việc của silver | Tách bronze thành 1 model / 1 bảng nguồn; chuyển join sang silver |
| 2 | Có **2 file source** trùng nhau; source `raw` trỏ sai schema (`dbo`) | Dư thừa, gây nhầm lẫn | Gộp thành 1 file `models/bronze/_sources.yml` |
| 3 | `brnz_example.sql` là file mẫu thừa | Code rác | Xóa |
| 4 | `gld_customer_metrics.avg_order_value` = trung bình **dòng** đơn hàng, không phải trung bình **đơn hàng** | Sai logic SQL (10đ) | `total_revenue / nullif(total_orders, 0)` |
| 5 | `gld_sales_summary.online_orders` đếm **dòng**, không đếm **đơn** | Sai logic | `count(distinct case when ... then sales_order_id end)` |
| 6 | Mật khẩu ghi thẳng trong `profiles.yml`, `docker-compose.yml` | Vi phạm bảo mật, không làm được CI/CD nhiều môi trường | Dùng biến môi trường `env_var()` + file `.env` (không commit) + GitHub Secrets |
| 7 | DAG chạy mỗi 5 phút, không có cảnh báo, không chia tầng | Phần 3 yêu cầu daily/hourly, error handling, notification | Viết lại DAG (xem Phần 3) |
| 8 | `dbt/requirements.txt` ghi `dbt-core==1.7.3`, trong khi Dockerfile cài `dbt-core==1.8.7` | Lệch phiên bản → CI có thể chạy khác local | Thống nhất **dbt-core 1.8.7 + dbt-sqlserver 1.8.7** ở mọi nơi |
| 9 | Dữ liệu AdventureWorks là dữ liệu **cũ (năm 2014)** | Kiểm tra freshness sẽ luôn báo lỗi | Viết script mô phỏng "dữ liệu mới" (xem Phần 2) |
| 10 | Thư mục `logs/`, `target/`, `dbt_packages/`, `airflow/logs/`, `mdpdf.log` | Không được đưa lên Git | Thêm vào `.gitignore` |

---

## 5. Các quyết định kỹ thuật đã chốt

Những quyết định này áp dụng cho **cả nhóm**. Muốn đổi thì phải báo trưởng nhóm.

| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| D1 | **Phiên bản** | dbt-core **1.8.7**, dbt-sqlserver **1.8.7**, Airflow **2.7.1** (Python 3.9), SQL Server **2019** | Khớp với Docker đang chạy |
| D2 | **SQL Server trong GitHub Actions** | Máy ảo GitHub **không** kết nối được SQL Server trên laptop. → Trong workflow, dựng SQL Server + container dbt bằng **chính `docker-compose.yml` của dự án** (thêm file `docker-compose.ci.yml` để ghi đè), restore AdventureWorks rồi mới chạy dbt | CI chạy giống hệt local, không phải cài ODBC driver trên runner |
| D3 | **Môi trường dev/staging/prod** | Cùng 1 database, **khác schema**: target `dev` → `dev_bronze`, `dev_silver`, `dev_gold`; `staging` → `staging_*`; `prod` → `prod_*`; `ci` → `ci_*` | Đơn giản, không cần thêm server; dbt tự ghép tên schema |
| D4 | **Bí mật (mật khẩu)** | `profiles.yml` dùng `{{ env_var('DBT_USER') }}`, `{{ env_var('DBT_ENV_SECRET_PASSWORD') }}`... (tiền tố `DBT_ENV_SECRET_` giúp dbt tự che mật khẩu trong log); local đọc từ `.env` (có `.env.example` mẫu); GitHub dùng **Secrets** | Không lộ mật khẩu, dễ đổi theo môi trường |
| D5 | **Thông báo** | **Discord webhook** (miễn phí, tạo trong 1 phút). Slack cũng được. Dùng chung cho Airflow và GitHub Actions | Đáp ứng "notifications" ở Phần 3 và Phần 4 |
| D6 | **Rollback** | Mỗi lần deploy prod thành công → gắn **git tag** `prod-YYYYMMDD-HHMM`. Trước khi deploy → **backup bảng gold**. Deploy lỗi → khôi phục backup / deploy lại tag trước. Có thêm workflow rollback chạy tay | Đáp ứng "rollback capability" + "deployment history" |
| D7 | **Repo & duyệt trước khi lên prod** | Repo **public** (giáo viên đã đồng ý). Dùng **GitHub Environments** với *required reviewers* (trưởng nhóm duyệt) cho `production` | Repo public dùng miễn phí đầy đủ tính năng Environments; đúng chuẩn công nghiệp |
| D8 | **Lint** | Python: `flake8` + `black`; SQL: `sqlfluff` (dialect `tsql`, templater `jinja`); chạy cả ở **pre-commit** (local) và CI | Đúng yêu cầu Phần 4A |
| D9 | **Chọn model theo tầng** | Airflow và CI chọn model theo **thư mục**: `--select path:models/bronze`, `path:models/silver`, `path:models/gold` (không phụ thuộc tag) | B thêm/đổi tên model thoải mái mà DAG của C không phải sửa → làm song song được |
| D10 | **Biến môi trường cho container** | Mọi container đọc biến từ file `.env` (qua `env_file:`). **Chỉ A** sửa `docker-compose.yml`, và sửa **một lần** ở Phần 0 cho cả dbt lẫn Airflow (`DBT_*`, `NOTIFY_WEBHOOK_URL`, `AIRFLOW_VAR_DBT_TARGET`, `AIRFLOW_CONN_MSSQL_DEFAULT`) | Tránh 2 người cùng sửa 1 file; C không phải chờ A khi làm DAG |

> ⚠️ **Repo public = ai cũng đọc được.** Tuyệt đối không commit mật khẩu, file `.env`, URL webhook. Mọi bí mật chỉ nằm trong **GitHub Secrets** (xem D4).

---

## 6. Danh sách công việc chi tiết (theo phần chấm điểm)

Ký hiệu: **[MVP]** = bắt buộc để qua môn · **[FULL]** = cần cho điểm tối đa · **[BONUS]**.
Người làm: **A** = Trưởng nhóm (bạn) · **B** = Thành viên B · **C** = Thành viên C.

### Phần 0 — Nền tảng (không chấm điểm nhưng mọi phần khác phụ thuộc vào nó) · **A**

| Việc | Cách làm |
|---|---|
| Cả 3 người chạy được Docker | Làm theo `0. NEW_COMPUTER_SETUP.md`; kiểm tra `dbt debug` và Airflow UI http://localhost:8080 |
| Tạo Git repo + GitHub | `git init`, `.gitignore`, commit đầu; tạo repo GitHub, mời 2 thành viên |
| Chiến lược nhánh | `main` (prod) · `develop` (dev) · `feature/<tên>` · `fix/<tên>`. Bật **branch protection** cho `main`, `develop`: bắt buộc PR + CI xanh + 1 người duyệt |
| Bỏ mật khẩu khỏi code | `profiles.yml` dùng `env_var()`; tạo `.env.example`; truyền biến vào container dbt **và** Airflow (theo D10) |
| Khai báo các target | `profiles.yml` có `dev`, `staging`, `prod`, `ci` (khác nhau ở `schema`) |
| Thống nhất phiên bản | Sửa `dbt/requirements.txt` cho khớp Dockerfile (dbt 1.8.7) |
| pre-commit | `.pre-commit-config.yaml`: black, flake8, sqlfluff, check-yaml, check-added-large-files, detect-private-key |

### Phần 1 — dbt Data Models (25đ) · **B**

**Bronze (8đ)** — [MVP: ≥2 model] [FULL: ≥3 bảng nguồn, làm sạch, freshness, mô tả mọi cột]
- 1 model bronze = 1 bảng nguồn, materialized `view`. Dự kiến 7 model:
  `brnz_customer`, `brnz_person`, `brnz_sales_order_header`, `brnz_sales_order_detail`, `brnz_product`, `brnz_product_subcategory`, `brnz_product_category`.
- Làm sạch: đổi tên cột sang `snake_case`, `cast` kiểu dữ liệu, `trim` chuỗi, chuẩn hóa NULL. **Không join** ở bronze.
- Gộp source vào 1 file `_sources.yml`, khai báo `loaded_at_field` + `freshness` (chi tiết ở Phần 2).
- Mô tả **mọi cột** trong `_bronze__models.yml`.
- *(Mẹo làm song song)* Khi tách bronze, **giữ nguyên tên cột đầu ra của silver** → gold, test và dashboard đang dùng silver/gold không bị vỡ.

**Silver (8đ)** — [FULL: ≥2 model, join nhiều bronze, logic nghiệp vụ, có test]
- `slvr_customers` = customer + person (họ tên, loại khách: cá nhân/cửa hàng).
- `slvr_products` = product + subcategory + category (cờ ngừng bán, phân khúc giá).
- `slvr_sales_orders` = order header + order detail (kênh online/offline, có giảm giá, số ngày giao hàng...).
- Materialized `table`.

**Gold (9đ)** — [MVP: ≥1 model] [FULL: ≥2 model, aggregation, tối ưu hiệu năng, sẵn sàng phân tích]
- Giữ và **sửa lỗi logic** 3 model hiện có: `gld_customer_metrics`, `gld_product_performance`, `gld_sales_summary`.
- *(Khuyến nghị)* Thêm 1 model hấp dẫn khi demo, ví dụ `gld_customer_segments` (phân nhóm khách hàng theo RFM) hoặc `gld_monthly_sales`.
- **Hiệu năng (3đ):** materialized `table`; model lớn (`slvr_sales_orders`, ~121 nghìn dòng) chuyển sang `incremental`; thêm index qua `post_hook` cho cột hay lọc/join. **Đo thời gian trước/sau** và ghi số liệu vào `docs/PERFORMANCE.md`.

**Tài liệu & lineage:** mọi model/cột đều có `description`; dùng `{% docs %}` cho mô tả dài.

### Phần 2 — Automated Testing (20đ) · **B**

**Schema tests (8đ)** — [MVP: `not_null` + `unique` cho khóa chính]
- `not_null` + `unique` cho **khóa chính của mọi model**.
- Khóa ghép: `dbt_utils.unique_combination_of_columns` (vd. `sales_order_id` + `order_detail_id`).
- `relationships` cho khóa ngoại: `slvr_sales_orders.customer_id → slvr_customers`, `product_id → slvr_products`...
- `accepted_values`: `status` ∈ {1..6}, `order_channel` ∈ {'Online','Offline'}, các cờ ∈ {0,1}.

**Custom tests (7đ)** — [FULL: ≥3 generic test tự viết]
- Generic tests trong `dbt/tests/generic/` (dự kiến 4 test, dư 1 cho an toàn):
  1. `positive_value` — giá trị cột > 0 (hoặc ≥ 0).
  2. `valid_date_range` — ngày nằm trong khoảng [min, max] và không ở tương lai.
  3. `date_not_before` — cột ngày A ≥ cột ngày B (vd. `ship_date ≥ order_date`).
  4. `row_count_greater_than` — bảng có ít nhất N dòng.
- Singular tests (kiểm tra nghiệp vụ) trong `dbt/tests/`: tổng doanh thu gold = tổng `line_total` silver; `profit_margin_pct` trong khoảng hợp lý...
- Dùng `severity: warn` cho kiểm tra "mềm", `error` cho kiểm tra bắt buộc; `store_failures` để lưu dòng lỗi.

**Source freshness (5đ)** — [FULL]
- Mọi bảng nguồn có `loaded_at_field: ModifiedDate`, `warn_after: 24 hour`, `error_after: 48 hour`; ghi rõ độ trễ dữ liệu kỳ vọng trong `description`/`meta`.
- ⚠️ AdventureWorks là dữ liệu năm 2014 → viết `scripts/simulate_new_data.sql` cập nhật/thêm vài dòng với `ModifiedDate = GETDATE()`. Chạy script trước `dbt source freshness` (trong CI và khi demo). Khi demo: chạy freshness **trước** script để thấy WARN/ERROR, chạy **sau** script để thấy PASS.

**Tài liệu test:** `docs/TESTING.md`: bảng liệt kê test, mục đích, mức độ nghiêm trọng, cách chạy.

### Phần 3 — Airflow Orchestration (15đ) · **C**

[MVP: 1 DAG chạy được, có phụ thuộc, lịch daily/manual] [FULL: thứ tự đúng, retry, kiểm tra chất lượng, thông báo lỗi, tài liệu]

Viết lại `airflow/dags/dbt_dag.py` thành DAG `dbt_pipeline`:

```
check_sqlserver ─► dbt_deps ─► source_freshness
   ─► [bronze: run ─► test] ─► [silver: run ─► test] ─► [gold: run ─► test]
   ─► data_quality_checks ─► dbt_docs_generate ─► notify_success
```

- Giữ cách gọi dbt hiện tại (`docker exec <container dbt> dbt ...`), chạy theo tầng bằng `--select path:models/bronze` ... (theo D9); dùng **TaskGroup** cho mỗi tầng.
- `schedule="@daily"`, `catchup=False`, `start_date` cố định.
- Xử lý lỗi: `retries=2`, `retry_delay=5 phút`, `retry_exponential_backoff=True`, `execution_timeout`.
- `on_failure_callback` → gửi Discord/Slack (URL webhook lấy từ biến môi trường / Airflow Variable, **không** ghi trong code).
- `data_quality_checks`: dùng `SQLCheckOperator` (provider mssql đã cài) kiểm tra bảng gold có dữ liệu, ngày mới nhất hợp lệ.
- Tài liệu: `doc_md` cho DAG và từng task; `tags`.
- Có thể chọn target (dev/prod) qua Airflow Variable `dbt_target`.
- Viết `tests/test_dag_integrity.py` (pytest: DAG import không lỗi, đúng số task, không có vòng lặp) để **A** đưa vào CI.
- Code phải pass `black` + `flake8`.

### Phần 4 — CI/CD & Deployment Automation (35đ) · **A**

#### 4A. CI — Continuous Integration (10đ)

| Workflow | Kích hoạt | Nội dung |
|---|---|---|
| `.github/workflows/ci.yml` | `pull_request` vào `develop`, `main` | **Job lint-python:** `black --check`, `flake8`, pytest DAG integrity · **Job lint-sql:** `sqlfluff lint dbt/models` · **Job dbt-ci:** dựng SQL Server bằng docker compose → restore AdventureWorks → tạo user → chạy script dữ liệu mới → `dbt deps` → `dbt compile` → `dbt build --target ci` → `dbt source freshness` → `dbt docs generate` → upload `target/` + log làm artifact |
| `.github/workflows/pr-validation.yml` | `pull_request` | Tiêu đề PR đúng Conventional Commits (`feat: ...`); chặn file > 5 MB; kiểm tra merge conflict |

Script dùng chung (dùng cả ở local và CI): `scripts/init_sqlserver.sh` (chờ SQL Server sẵn sàng, restore DB, tạo login dbt). Tạo ở file `02_...`.

#### 4B. CD — Deployment Automation (20đ)

**Cơ bản (12đ)** [MVP] — `.github/workflows/deploy.yml`, kích hoạt khi `push` vào `develop`/`main`:
`dbt deps` → `dbt run` → `dbt test` → hiển thị xanh/đỏ → upload log deploy làm artifact.

**Nâng cao (8đ)** [FULL] — cùng file `deploy.yml`, chia thành các job:

```
pre_deploy_validation ─► deploy ─► post_deploy_health_check ─► notify
(dbt debug, compile,      (backup gold,   (đếm dòng gold > 0,          (Discord + GitHub Job Summary
 sqlfluff)                 dbt run/test    freshness, ngày mới nhất)    + comment vào commit)
                           --target <env>)        │
                                                  └── lỗi ─► rollback tự động (khôi phục backup)
```

- **Theo môi trường:** `develop → dev`; `main → staging → (trưởng nhóm duyệt) → prod`. Dùng `environment:` của GitHub → GitHub tự lưu **lịch sử deployment**.
- **Badges** trạng thái CI/Deploy trong README.
- **Rollback:**
  - Tự động: test sau deploy lỗi → khôi phục bảng gold từ backup.
  - Thủ công: `.github/workflows/rollback.yml` (`workflow_dispatch`, nhập tag `prod-...` cần quay về) → checkout tag đó → `dbt run --target prod`.
- Deploy prod thành công → tạo tag `prod-YYYYMMDD-HHMM`.

#### 4C. Tài liệu & giám sát deployment (5đ)

- `docs/DEPLOYMENT_RUNBOOK.md`: quy trình deploy từng bước, ai duyệt, xử lý khi lỗi.
- `docs/ROLLBACK.md`: quy trình rollback tự động/thủ công.
- Lịch sử deployment: tab **Environments/Deployments** của GitHub + danh sách tag `prod-*`.
- Tỉ lệ thành công: `.github/workflows/deploy-report.yml` (chạy hằng tuần + chạy tay) dùng `gh api` thống kê số lần deploy thành công/thất bại → ghi vào Job Summary.

### Phần 5 — Documentation & Presentation (5đ) · **C** (+ cả nhóm)

> Không làm slide/video. Phần "Presentation" = **demo trực tiếp** theo kịch bản ở [mục 10](#kịch-bản-demo-trực-tiếp-15-phút).

| Sản phẩm | Nội dung | Người viết |
|---|---|---|
| `README.md` (viết lại) | Tổng quan, sơ đồ kiến trúc, cài đặt < 30 phút, cách chạy pipeline, troubleshooting, badges, **bảng đóng góp của từng thành viên**, **ghi chú có dùng AI** (đề bài yêu cầu khai báo) | C (A thêm phần CI/CD) |
| `docs/ARCHITECTURE.md` + `docs/images/architecture.png` | Sơ đồ luồng dữ liệu (vẽ bằng draw.io / Excalidraw) | C |
| `docs/SETUP_GUIDE.md` | Hướng dẫn cho người mới từng bước | C |
| `docs/TROUBLESHOOTING.md` | Lỗi thường gặp + cách sửa (gom từ quá trình làm) | Cả nhóm góp, C tổng hợp |
| `docs/TESTING.md`, mô tả model (dbt docs) | | B |
| `docs/DEPLOYMENT_RUNBOOK.md`, `docs/ROLLBACK.md` | | A |
| `docs/DEMO_SCRIPT.md` | Kịch bản demo trực tiếp, lệnh cần gõ, ai nói phần nào, phương án dự phòng khi demo lỗi | C (cả nhóm góp ý) |

### Bonus 1 — Monitoring Dashboard (+5) · **C**

- Thêm file **riêng** `docker-compose.monitoring.yml` chạy **Grafana** (cổng 3000) → **không sửa** `docker-compose.yml` gốc (đề bài khuyên không sửa hạ tầng; tool thêm thì phải giải thích + ghi tài liệu).
- Cấu hình bằng code (provisioning): `monitoring/grafana/provisioning/datasources/*.yml`, `.../dashboards/*.json`.
- Nguồn dữ liệu:
  - **PostgreSQL metadata của Airflow** (bảng `dag_run`, `task_instance`) → tỉ lệ thành công DAG, thời gian chạy mỗi task, các lần lỗi gần nhất.
  - **SQL Server** → số dòng các bảng gold, ngày dữ liệu mới nhất; *(nâng cao)* kết quả test dbt: thêm task Airflow đọc `target/run_results.json` ghi vào bảng `monitoring.dbt_test_results`.
- Chụp ảnh dashboard đưa vào README.

### Bonus 2 — Data Lineage Visualization (+5) · **B** (A hỗ trợ phần workflow)

- `dbt docs generate` đã có sẵn lineage graph tương tác → **đưa lên GitHub Pages tự động** bằng workflow `.github/workflows/docs-pages.yml` (chạy khi merge vào `main`).
- Thêm `models/exposures.yml` khai báo "người dùng cuối" (dashboard Grafana, báo cáo doanh thu) → lineage hiển thị đến tận nơi dùng dữ liệu.
- Gắn link trang lineage + ảnh chụp lineage vào README.

### Bonus 4 — Multi-environment dev/staging/prod (+5) · **A**

- 3 target trong `profiles.yml` (theo D3) + 3 **GitHub Environments**: `dev`, `staging`, `production` (mỗi môi trường có secrets riêng; `production` cần trưởng nhóm duyệt).
- Luồng: `feature → PR → develop` (deploy **dev**) → `PR develop → main` (deploy **staging** tự động → duyệt → **production**).
- Airflow chọn môi trường qua Variable `dbt_target`.
- Ghi rõ trong runbook: môi trường nào dùng để làm gì.

---

## 7. Cấu trúc thư mục mục tiêu

```
dbt_airflow_project/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # A – CI cho Pull Request
│   │   ├── pr-validation.yml         # A – kiểm tra PR
│   │   ├── deploy.yml                # A – CD dev/staging/prod
│   │   ├── rollback.yml              # A – rollback thủ công
│   │   ├── deploy-report.yml         # A – thống kê deployment
│   │   └── docs-pages.yml            # B – lineage lên GitHub Pages
│   └── pull_request_template.md      # A
├── airflow/
│   ├── dags/dbt_dag.py               # C – DAG dbt_pipeline
│   └── dags/utils/notifications.py   # C – gửi Discord/Slack
├── dbt/
│   ├── models/
│   │   ├── bronze/  (_sources.yml, _bronze__models.yml, brnz_*.sql)   # B
│   │   ├── silver/  (_silver__models.yml, slvr_*.sql)                 # B
│   │   ├── gold/    (_gold__models.yml, gld_*.sql)                    # B
│   │   ├── docs.md                    # B – doc blocks
│   │   └── exposures.yml              # B – Bonus 2
│   ├── tests/
│   │   ├── generic/                   # B – ≥3 custom generic tests
│   │   └── assert_*.sql               # B – singular tests
│   ├── macros/                        # B (nếu cần)
│   ├── dbt_project.yml, packages.yml
│   └── profiles.yml                   # A – dùng env_var(), 4 target
├── scripts/
│   ├── init_sqlserver.sh              # A – restore DB + tạo login dbt (local + CI)
│   ├── health_check.sql               # A
│   └── simulate_new_data.sql          # B
├── monitoring/grafana/provisioning/   # C – Bonus 1
├── tests/test_dag_integrity.py        # C
├── docs/                              # ARCHITECTURE, SETUP_GUIDE, TESTING, PERFORMANCE, DEPLOYMENT_RUNBOOK, ROLLBACK, TROUBLESHOOTING, DEMO_SCRIPT, images/
├── project/                           # ← các file hướng dẫn này
├── docker-compose.yml                 # gốc – hạn chế sửa
├── docker-compose.ci.yml              # A – ghi đè cho CI
├── docker-compose.monitoring.yml      # C – Grafana
├── .env.example                       # A
├── .pre-commit-config.yaml, .sqlfluff, .flake8, pyproject.toml   # A
├── .gitignore                         # A
└── README.md                          # C + A
```

---

## 8. Quy ước làm việc nhóm

### 8.1. Git workflow

1. Luôn tạo nhánh từ `develop`: `git checkout develop && git pull && git checkout -b feature/bronze-refactor`.
2. Commit theo **Conventional Commits** (đề bài chấm phần này):
   `feat: add silver customers model` · `fix: correct avg_order_value` · `test: add positive_value generic test` · `docs: update setup guide` · `ci: add sqlfluff job` · `refactor: ...` · `chore: ...`
3. Mở **Pull Request vào `develop`**, tiêu đề cũng theo Conventional Commits. CI phải xanh + **1 người khác duyệt** mới được merge.
4. **Không ai push thẳng** vào `develop`/`main`. Chỉ trưởng nhóm mở PR `develop → main` (phát hành).
5. PR nhỏ, mỗi PR một việc (dễ review, dễ rollback).

### 8.2. Quy ước đặt tên (thống nhất ngay ngày 1)

| Thứ | Quy ước |
|---|---|
| Model | `brnz_<bảng>`, `slvr_<thực thể>`, `gld_<chủ đề>`; cột `snake_case` |
| File YAML | `_sources.yml`, `_bronze__models.yml`, `_silver__models.yml`, `_gold__models.yml` |
| Chọn model theo tầng | `--select path:models/bronze` / `silver` / `gold` (theo D9) |
| Target dbt | `dev`, `staging`, `prod`, `ci` |
| Biến môi trường | `DBT_TARGET`, `DBT_SERVER`, `DBT_PORT`, `DBT_DATABASE`, `DBT_USER`, `DBT_ENV_SECRET_PASSWORD`, `SA_PASSWORD`, `POSTGRES_PASSWORD`, `AIRFLOW_FERNET_KEY`, `AIRFLOW_ADMIN_PASSWORD`, `DOCKER_GID`, `NOTIFY_WEBHOOK_URL` (mẫu đầy đủ: `.env.example`) |
| GitHub Secrets | `SA_PASSWORD`, `DBT_ENV_SECRET_PASSWORD`, `NOTIFY_WEBHOOK_URL` |
| Tag phát hành | `prod-YYYYMMDD-HHMM` |

### 8.3. Giao tiếp

- Họp nhanh 15 phút, **2–3 lần/tuần**: hôm qua làm gì, hôm nay làm gì, đang vướng gì.
- Theo dõi công việc bằng **GitHub Projects** (bảng Kanban) hoặc Issues — đồng thời là bằng chứng đóng góp khi bị đánh giá chéo.
- Gặp lỗi mới → ghi ngay vào `docs/TROUBLESHOOTING.md` (đỡ phải viết lại cuối kỳ).

---

## 9. Phân công 3 thành viên

### 9.1. Tổng quan vai trò

| | **A – Trưởng nhóm (bạn)** | **B – Data Engineer (dbt)** | **C – Orchestration & Docs** |
|---|---|---|---|
| Vai trò | Kiến trúc, DevOps, CI/CD, release manager | Mô hình dữ liệu & chất lượng dữ liệu | Airflow, giám sát, tài liệu, kịch bản demo |
| Phần chính | **Phần 0, Phần 4 (35đ)** | Phần 1 (25đ), Phần 2 (20đ) | Phần 3 (15đ), Phần 5 (5đ) |
| Bonus | **Bonus 4** (multi-env) | Bonus 2 (lineage) | Bonus 1 (Grafana) |
| Ước lượng | ~30–35 giờ | ~25–30 giờ | ~20–25 giờ |

**Vì sao trưởng nhóm giữ CI/CD?**
- Đây là phần **nặng điểm nhất (35đ)** và **khó nhất** (dựng SQL Server trong GitHub Actions, nhiều môi trường, rollback).
- CI/CD **chạm vào sản phẩm của mọi người** (chạy model của B, lint DAG của C) → người làm phải nắm toàn hệ thống → đúng vai trò trưởng nhóm.
- Trưởng nhóm kiểm soát `main` và quyền duyệt production → đảm bảo chất lượng bài nộp.

### 9.2. Chi tiết công việc từng người

**A — Trưởng nhóm**
1. Phần 0: repo GitHub, nhánh, branch protection, `.gitignore`, pre-commit, đưa mật khẩu ra biến môi trường, 4 target trong `profiles.yml`, thống nhất phiên bản. **Phải xong trong 2 ngày đầu** vì cả nhóm làm trên nền này.
2. `docker-compose.ci.yml` + `scripts/init_sqlserver.sh` (đã có từ file 02).
3. `ci.yml`, `pr-validation.yml` (CI — 4A).
4. `deploy.yml` bản đơn giản → **đạt MVP sớm**; sau đó nâng cấp: pre-check, backup, health check, thông báo, tag, rollback tự động (4B).
5. GitHub Environments dev/staging/production + duyệt prod (Bonus 4).
6. `rollback.yml`, `deploy-report.yml`, `DEPLOYMENT_RUNBOOK.md`, `ROLLBACK.md`, badges (4C).
7. Review & merge PR của B và C; phát hành `develop → main`; điều phối buổi tập demo.

**B — Data Engineer**
1. Tách lại bronze (1 model / 1 bảng nguồn), gộp sources, khai báo freshness, `simulate_new_data.sql`.
2. Silver (3 model) + gold (sửa lỗi 3 model, thêm 1 model mới) + tối ưu hiệu năng có số liệu đo.
3. Mô tả mọi model/cột, doc blocks, tags.
4. Toàn bộ test: schema tests, ≥3 custom generic tests, singular tests, `docs/TESTING.md`.
5. SQL phải pass `sqlfluff`.
6. Bonus 2: `exposures.yml` + `docs-pages.yml` (A review workflow).

**C — Orchestration & Docs**
1. Viết lại DAG `dbt_pipeline` (TaskGroup theo tầng, retry, timeout, SQL check, thông báo lỗi, `doc_md`).
2. `airflow/dags/utils/notifications.py` (A dùng cùng webhook cho GitHub Actions).
3. `tests/test_dag_integrity.py`; code pass black/flake8.
4. Bonus 1: Grafana + dashboard dạng code (+ bảng kết quả test dbt nếu kịp).
5. Phần 5: README, ARCHITECTURE + sơ đồ, SETUP_GUIDE, TROUBLESHOOTING, `DEMO_SCRIPT.md`.

### 9.3. Làm song song: có cần chờ nhau không?

**Trả lời ngắn:** sau **2 ngày đầu**, khoảng **90% công việc làm song song được**: mỗi người làm phần của mình mà không phải chờ ai. Nhưng **không hoàn toàn độc lập 100%**. Có vài **điểm bàn giao** nhỏ (bảng dưới) và **một buổi ghép nối** cuối tuần 2.

Vì sao làm song song được:
- **Model cũ đã chạy được** → A dựng CI/CD ngay trên model cũ, không phải chờ B viết lại.
- **DAG chọn model theo thư mục** (D9) → B thêm/đổi tên model, DAG của C vẫn chạy.
- **Chỉ A sửa `docker-compose.yml`, sửa 1 lần** (D10) → C không phải chờ A khi làm DAG.
- **Mỗi người sở hữu thư mục riêng** (bảng 9.4) → gần như không có merge conflict.
- Mọi tên gọi (target, biến môi trường, tên model) **đã chốt ở mục 8.2** → không phải hỏi nhau.

#### Giai đoạn 1 — Ngày 1–2: CHƯA song song hoàn toàn

A làm Phần 0. B và C **không bị chặn**: trong lúc chờ, cài Docker, chạy pipeline cũ trên máy mình, đọc tài liệu, viết code ở local (chưa push).

#### Giai đoạn 2 — Từ ngày 3: song song, chỉ có các điểm bàn giao sau

| # | Ai cần | Cần gì | Từ ai | Khi nào | Nếu chưa có thì sao? |
|---|---|---|---|---|---|
| 1 | B, C | Repo + `.env.example` + `profiles.yml` mới + `docker-compose.yml` đã thêm biến | A | Hết ngày 2 | B, C vẫn code ở local; push sau |
| 2 | B, C | Cấu hình lint (`.sqlfluff`, `.flake8`, pre-commit) | A | Hết ngày 2 | Code xong rồi chạy lint sau; sửa format mất ít phút |
| 3 | A | Webhook Discord | C tạo, gửi riêng cho A (**không** gửi lên repo) | Tuần 1 | A làm trước phần còn lại, thêm thông báo sau |
| 4 | A | `tests/test_dag_integrity.py` | C | Giữa tuần 2 | Job trong CI tự bỏ qua nếu file chưa tồn tại |
| 5 | C | Bảng gold ổn định (tên cột) để vẽ dashboard | B | Đầu tuần 2 | C làm trước các biểu đồ đọc **metadata Airflow** (không phụ thuộc B) |
| 6 | B | Tên/URL dashboard Grafana để khai báo `exposures.yml` | C | Tuần 3 | Khai báo trước, sửa URL sau |

> **Lưu ý về CI:** khi A bật CI bắt buộc (branch protection), PR của B và C **phải pass lint** mới merge được. Vì vậy B và C nên cài **pre-commit** ngay khi A xong Phần 0, để lỗi format được sửa tự động lúc commit, không đợi đến lúc CI báo đỏ.

#### Giai đoạn 3 — Cuối tuần 2: ghép nối (cả nhóm, ~2–3 giờ)

Ba phần chạy riêng lẻ chưa chắc đã chạy được cùng nhau. Cả nhóm ngồi cùng nhau chạy toàn bộ luồng **một lần**:

1. Merge mọi PR vào `develop` → CI xanh → deploy dev thành công.
2. Airflow chạy DAG mới trên model mới của B → test pass → thông báo Discord.
3. Grafana hiển thị đúng dữ liệu của lần chạy đó.
4. PR `develop → main` → staging → duyệt → prod → tag.

Lỗi phát sinh → ghi vào `docs/TROUBLESHOOTING.md`, chia người sửa ngay.

### 9.4. Ai sở hữu file nào (để tránh conflict)

| Người | Được sửa | Muốn sửa file của người khác thì |
|---|---|---|
| A | `.github/`, `scripts/init_sqlserver.sh`, `scripts/health_check.sql`, `dbt/profiles.yml`, `docker-compose.yml`, `docker-compose.ci.yml`, `.env.example`, file cấu hình lint, `.gitignore`, `docs/DEPLOYMENT_RUNBOOK.md`, `docs/ROLLBACK.md` | Mở PR, nhờ chủ file review |
| B | `dbt/models/`, `dbt/tests/`, `dbt/macros/`, `dbt/dbt_project.yml`, `dbt/packages.yml`, `scripts/simulate_new_data.sql`, `docs/TESTING.md`, `docs/PERFORMANCE.md`, `.github/workflows/docs-pages.yml` (A review) | Như trên |
| C | `airflow/`, `tests/`, `monitoring/`, `docker-compose.monitoring.yml`, `README.md`, `docs/ARCHITECTURE.md`, `docs/SETUP_GUIDE.md`, `docs/TROUBLESHOOTING.md`, `docs/DEMO_SCRIPT.md` | Như trên |

- `README.md` dùng chung: C sở hữu khung; A và B **chỉ sửa mục của mình** (CI/CD; Models & Tests).
- Mỗi người **review ít nhất 1 PR của người khác mỗi tuần** → ai cũng hiểu toàn hệ thống để trả lời câu hỏi khi demo.

---

## 10. Kế hoạch 3 tuần

### Tuần 1 — Nền tảng + đạt MVP (60 điểm)

| Ngày | A (trưởng nhóm) | B | C |
|---|---|---|---|
| 1–2 | Phần 0 (repo public, nhánh, env vars, pre-commit) | Cài Docker, chạy được pipeline cũ; đọc kỹ data AdventureWorks | Cài Docker; tạo Discord webhook; tìm hiểu DAG cũ |
| 3–5 | `docker-compose.ci.yml`, `ci.yml` | Tách bronze + sources + freshness | Viết lại DAG + thông báo lỗi |
| 6–7 | `deploy.yml` bản đơn giản, `pr-validation.yml` | Silver + test `not_null`/`unique` | DAG integrity test; README khung |

**🎯 Mốc cuối tuần 1:** CI chạy trên PR, deploy tự chạy khi merge `develop`, DAG chạy được, model + test cơ bản → **đạt MVP 60đ**.

### Tuần 2 — Đủ 100 điểm

| A | B | C |
|---|---|---|
| Environments dev/staging/prod, duyệt prod, pre-check, backup, health check, thông báo, tag, rollback tự động | Gold (sửa lỗi + model mới), incremental/index + đo hiệu năng; relationships, accepted_values, ≥3 custom tests, singular tests; mô tả mọi cột | SQL check trong DAG, Variable `dbt_target`; Grafana + dashboard; ARCHITECTURE + sơ đồ |

**🎯 Mốc cuối tuần 2:** mọi yêu cầu bắt buộc hoàn tất. **Đóng băng tính năng (feature freeze)** — tuần 3 chỉ làm bonus, tài liệu, sửa lỗi.

### Tuần 3 — Bonus, tài liệu, thuyết trình

| A | B | C |
|---|---|---|
| `rollback.yml`, `deploy-report.yml`, runbook, rollback doc, badges; phát hành `develop → main` bản `v1.0` | `exposures.yml`, `docs-pages.yml` (lineage lên Pages), `TESTING.md`, `PERFORMANCE.md` | README hoàn chỉnh, SETUP_GUIDE, TROUBLESHOOTING, `DEMO_SCRIPT.md` |

**Cả nhóm:** tập demo **ít nhất 2 lần** trên máy sẽ dùng thuyết trình; nhờ một người ngoài nhóm cài dự án theo SETUP_GUIDE (mục tiêu < 30 phút).

### Kịch bản demo trực tiếp 15 phút

1. (2') Giới thiệu bài toán + kiến trúc.
2. (3') Tạo PR sửa một model → CI chạy: lint, test, kiểm tra PR.
3. (3') Merge → deploy dev → merge `main` → staging → duyệt → prod; thông báo về Discord.
4. (2') Airflow UI: DAG theo tầng, xem log, minh họa retry/lỗi.
5. (2') Grafana dashboard + trang lineage trên GitHub Pages.
6. (1') Minh họa rollback.
7. (2') Khó khăn & bài học.

---

## 11. Checklist nộp bài + rủi ro cần lưu ý

### 11.1. Checklist nộp bài (đối chiếu đề bài)

- [ ] Repo GitHub có `main`, `develop`, các nhánh `feature/*`; commit theo Conventional Commits
- [ ] ≥3 bronze, ≥2 silver, ≥2 gold; chạy `dbt build` thành công
- [ ] Mọi model/cột có mô tả; lineage xem được
- [ ] not_null, unique, relationships, accepted_values; ≥3 custom generic tests; freshness cho mọi source
- [ ] DAG daily, phụ thuộc đúng thứ tự, retry, kiểm tra chất lượng, thông báo lỗi, có tài liệu
- [ ] CI: compile + test dbt, flake8, black, sqlfluff, kiểm tra PR, sinh docs
- [ ] CD: merge `develop`/`main` → deps/run/test tự động, có log, xanh/đỏ rõ ràng
- [ ] dev/staging/prod, thông báo, badges, rollback, pre-check, health check
- [ ] Runbook, lịch sử deployment, tỉ lệ thành công, quy trình rollback
- [ ] README, sơ đồ kiến trúc (PDF/ảnh), SETUP_GUIDE, TROUBLESHOOTING, tài liệu model
- [ ] Demo trực tiếp 15 phút (đã tập ít nhất 2 lần)
- [ ] Bonus: Grafana, lineage trên Pages, multi-env
- [ ] README có bảng đóng góp từng thành viên + khai báo dùng công cụ AI

### 11.2. Rủi ro và cách phòng tránh

| Rủi ro | Phòng tránh |
|---|---|
| Dựng SQL Server trong CI chậm/lỗi (bước khó nhất) | A làm **ngay tuần 1**; tách thành script dùng chung; có vòng chờ SQL Server sẵn sàng thay vì `sleep` cố định |
| Freshness luôn lỗi do dữ liệu cũ | Script `simulate_new_data.sql` (mục Phần 2) |
| Lộ mật khẩu / webhook lên GitHub | `.env` trong `.gitignore`; pre-commit `detect-private-key`; chỉ dùng GitHub Secrets |
| Máy thành viên yếu RAM (SQL Server cần ~2 GB) | Tắt ứng dụng nặng khi chạy; không bật Grafana khi không cần |
| Thành viên dùng Mac chip Apple (M1/M2/M3) | Image SQL Server chỉ có bản amd64 → bật giả lập Rosetta trong Docker Desktop |
| Merge xung đột vì nhiều người sửa cùng file | Mỗi người sở hữu thư mục riêng (mục 7); PR nhỏ; luôn `git pull` `develop` trước khi tạo nhánh |
| Một thành viên chậm tiến độ | Mốc kiểm tra cuối mỗi tuần; MVP xong ở tuần 1 nên còn thời gian bù |
| Vi phạm liêm chính học thuật | Không copy code nhóm khác; mọi người hiểu được code mình nộp; khai báo việc dùng AI trong README |

---

## 12. Danh sách tài liệu hướng dẫn tiếp theo

Các file hướng dẫn từng bước sẽ được tạo trong thư mục `project/` theo thứ tự làm việc:

| File | Nội dung | Người dùng chính |
|---|---|---|
| `01_CHUAN_BI_MOI_TRUONG.md` | Cài và kiểm tra Docker, chạy pipeline cũ, công cụ cần có | Cả nhóm |
| `02_GIT_GITHUB_VA_NEN_TANG.md` | Phần 0: repo, nhánh, branch protection, env vars, pre-commit | A |
| `03_DBT_MODELS.md` | Phần 1: bronze/silver/gold, tài liệu, hiệu năng | B |
| `04_DBT_TESTING.md` | Phần 2: schema, custom, singular tests, freshness | B |
| `05_AIRFLOW_DAG.md` | Phần 3: DAG mới, retry, SQL check, thông báo | C |
| `06_CI_PIPELINE.md` | Phần 4A: SQL Server trong GitHub Actions, ci.yml, pr-validation | A |
| `07_CD_VA_MULTI_ENV.md` | Phần 4B + Bonus 4: deploy dev/staging/prod, duyệt, thông báo | A |
| `08_ROLLBACK_VA_GIAM_SAT_DEPLOY.md` | Phần 4C: rollback, lịch sử, tỉ lệ thành công, runbook | A |
| `09_GRAFANA_MONITORING.md` | Bonus 1 | C |
| `10_LINEAGE_GITHUB_PAGES.md` | Bonus 2 | B |
| `11_TAI_LIEU_VA_DEMO.md` | Phần 5: README, sơ đồ, tài liệu, kịch bản demo trực tiếp | C + cả nhóm |
