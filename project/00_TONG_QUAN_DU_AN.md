# 00 — TỔNG QUAN DỰ ÁN DATAOPS (LÀM MỘT MÌNH)
## dbt + Apache Airflow + SQL Server + GitHub Actions

> File này trả lời 3 câu hỏi: **(1) Phải làm những gì? (2) Làm theo cách nào? (3) Làm theo thứ tự nào?**
> Hướng dẫn chi tiết từng bước nằm ở các file `01_...` → `11_...` (xem [mục 9](#9-lộ-trình-các-file-hướng-dẫn)).
>
> Đề bài gốc: [`4. DATAOPS_PROJECT_REQUIREMENTS.md`](../4.%20DATAOPS_PROJECT_REQUIREMENTS.md)

---

## Mục lục

1. [Dự án này là gì?](#1-dự-án-này-là-gì)
2. [Mục tiêu điểm và thứ tự ưu tiên](#2-mục-tiêu-điểm-và-thứ-tự-ưu-tiên)
3. [Kiến trúc sau khi hoàn thành](#3-kiến-trúc-sau-khi-hoàn-thành)
4. [Hiện trạng repo](#4-hiện-trạng-repo)
5. [Các quyết định kỹ thuật đã chốt](#5-các-quyết-định-kỹ-thuật-đã-chốt)
6. [Danh sách công việc chi tiết (theo phần chấm điểm)](#6-danh-sách-công-việc-chi-tiết-theo-phần-chấm-điểm)
7. [Cấu trúc thư mục mục tiêu](#7-cấu-trúc-thư-mục-mục-tiêu)
8. [Quy trình làm việc với Git](#8-quy-trình-làm-việc-với-git)
9. [Lộ trình các file hướng dẫn](#9-lộ-trình-các-file-hướng-dẫn)
10. [Kế hoạch 3 tuần](#10-kế-hoạch-3-tuần)
11. [Checklist nộp bài + rủi ro](#11-checklist-nộp-bài--rủi-ro)

---

## 1. Dự án này là gì?

Xây dựng một **pipeline dữ liệu tự động** theo tinh thần **DataOps** (áp dụng DevOps vào dữ liệu):

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

**Thông tin đề bài:** 3 tuần · 100 điểm · **qua môn = 60 điểm (MVP)** · bonus tối đa +15.
Đề bài thiết kế cho nhóm 3 người; ở đây **một người làm toàn bộ**, nên thứ tự ưu tiên ở mục 2 rất quan trọng.

> ⚠️ Docker đã được cung cấp sẵn và **không được chấm điểm**. Điểm nằm ở những gì xây **trên** Docker.

---

## 2. Mục tiêu điểm và thứ tự ưu tiên

| Phần | Điểm tối đa | Làm ở file |
|---|---|---|
| 1. dbt Data Models | 25 | `04` |
| 2. Automated Testing | 20 | `05` |
| 3. Airflow Orchestration | 15 | `06` |
| 4. CI/CD & Deployment Automation | **35** | `03`, `07`, `08` |
| 5. Documentation & Presentation | 5 | `03` (README tối thiểu), `09` |
| **Bonus 4** – Multi-environment dev/staging/prod | +5 | `07` |
| **Bonus 1** – Monitoring Dashboard (Grafana) | +5 | `10` |
| **Bonus 2** – Data Lineage Visualization | +5 | `11` |

> Không làm slide và video demo (giáo viên không yêu cầu). Buổi thuyết trình là **demo trực tiếp** trên hệ thống thật.

### Ba mốc điểm

| Mốc | Đạt được sau file | Điểm | Ý nghĩa |
|---|---|---|---|
| 🥉 **Mốc 1 — MVP** | `03` | **~60** | **Đã qua môn.** Model + test + DAG gốc vẫn chạy được; thêm CI, deploy cơ bản, README tối thiểu là đủ MVP |
| 🥈 **Mốc 2 — Đủ điểm** | `09` | **~100** | Làm đủ mọi yêu cầu bắt buộc |
| 🥇 **Mốc 3 — Bonus** | `10`, `11` | **+15** | Chỉ làm khi đã xong Mốc 2 |

> **Nguyên tắc vàng:** Bonus **không bù** cho phần bắt buộc bị thiếu. Luôn ưu tiên **Mốc 1 → Mốc 2 → Mốc 3**.
> Vì vậy file `03` làm **CI/CD trước**, để chắc chắn qua môn ngay tuần 1. Mọi thay đổi sau đó đều đi qua CI, nên vừa an toàn vừa tạo ra lịch sử Pull Request đẹp để chấm điểm.

---

## 3. Kiến trúc sau khi hoàn thành

```
                         ┌──────────────────────── GitHub ─────────────────────────┐
  Bạn                    │                                                          │
  (feature branch) ──PR──►  CI (ci.yml, pr-validation.yml)                          │
                         │   • flake8 + black (Python)  • sqlfluff (SQL)            │
                         │   • dbt compile + dbt build trên SQL Server tạm          │
                         │   • kiểm tra tiêu đề PR, kích thước file, conflict       │
                         │                                                          │
                         │  merge → develop ──► CD: deploy DEV                      │
                         │  merge → main    ──► CD: deploy STAGING ──(duyệt)──► PROD│
                         │       • pre-check → backup → dbt run/test → health check │
                         │       • thông báo Discord • tag phiên bản • rollback     │
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

## 4. Hiện trạng repo

### 4.1. Đã xong (file `01`, `02`)

| Thành phần | Trạng thái |
|---|---|
| Docker (5 container), AdventureWorks đã restore | ✅ |
| Repo public `farols1505/dbt-airflow-dataops`, nhánh `main` + `develop` (mặc định), được bảo vệ | ✅ |
| Mật khẩu ra khỏi code (`.env`, `env_var()`), 4 target `dev`/`staging`/`prod`/`ci` | ✅ |
| Schema riêng cho từng môi trường (`dev_bronze`...) nhờ macro `generate_schema_name` | ✅ |
| `docker-compose.yml`: tên project cố định, sửa lỗi `docker.sock`, cổng chỉ mở localhost, healthcheck | ✅ |
| `scripts/init_sqlserver.sh` (restore DB + tạo login dbt, dùng lại trong CI) | ✅ |
| Phiên bản dbt thống nhất 1.8.7; pre-commit (black, flake8, sqlfluff, commit message) | ✅ |
| Model gốc: 4 bronze, 3 silver, 3 gold, 18 test → `dbt build` = `PASS=28` | ✅ chạy được |
| DAG gốc `dbt_transform` (`dbt run >> dbt test`) | ✅ chạy được |

### 4.2. Còn phải sửa (ảnh hưởng trực tiếp tới điểm)

| # | Vấn đề | Vì sao mất điểm | Sửa ở file |
|---|---|---|---|
| 1 | Model bronze đang **join nhiều bảng** (vd. `brnz_customers` join `Person`) | Tiêu chí *"Proper layering and separation of concerns"* (8đ): bronze phải 1-1 với bảng nguồn | `04` |
| 2 | Có **2 file source** trùng nhau; source `raw` trỏ sai schema (`dbo`) | Dư thừa, gây nhầm lẫn | `04` |
| 3 | `brnz_example.sql` là file mẫu thừa | Code rác | `04` |
| 4 | `gld_customer_metrics.avg_order_value` = trung bình **dòng** đơn hàng, không phải **đơn hàng** | Sai logic SQL | `04` |
| 5 | `gld_sales_summary.online_orders` đếm **dòng**, không đếm **đơn** | Sai logic SQL | `04` |
| 6 | Dữ liệu AdventureWorks là dữ liệu **cũ (năm 2014)** | Kiểm tra freshness sẽ luôn báo lỗi | `05` (script mô phỏng dữ liệu mới) |
| 7 | DAG chạy mỗi 5 phút, không chia tầng, không cảnh báo | Phần 3 yêu cầu daily/hourly, error handling, notification | `06` |
| 8 | README là tài liệu gốc của giáo viên | Phần 5 | `03` (tối thiểu), `09` (đầy đủ) |

---

## 5. Các quyết định kỹ thuật đã chốt

| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| D1 | **Phiên bản** | dbt-core **1.8.7**, dbt-sqlserver **1.8.7**, Airflow **2.7.1** (Python 3.9), SQL Server **2019** | Khớp với Docker đang chạy |
| D2 | **SQL Server trong GitHub Actions** | Máy ảo GitHub **không** kết nối được SQL Server trên laptop. → Trong workflow, dựng SQL Server + container dbt bằng **chính `docker-compose.yml` của dự án** (+ file `docker-compose.ci.yml` ghi đè), rồi chạy `scripts/init_sqlserver.sh` | CI chạy giống hệt local, không phải cài ODBC driver trên runner |
| D3 | **Môi trường dev/staging/prod** | Cùng 1 database, **khác schema**: target `dev` → `dev_bronze`, `dev_silver`, `dev_gold`; `staging` → `staging_*`; `prod` → `prod_*`; `ci` → `ci_*`. Cần macro `dbt/macros/generate_schema_name.sql` (đã làm ở `02`) vì adapter dbt-sqlserver mặc định bỏ qua tiền tố target | Đơn giản, không cần thêm server |
| D4 | **Bí mật (mật khẩu)** | `profiles.yml` dùng `{{ env_var('DBT_USER') }}`, `{{ env_var('DBT_ENV_SECRET_PASSWORD') }}`... (tiền tố `DBT_ENV_SECRET_` giúp dbt tự che mật khẩu trong log); local đọc từ `.env` (mẫu: `.env.example`); GitHub dùng **Secrets** | Repo public: không được lộ mật khẩu |
| D5 | **Thông báo** | **Discord webhook** (miễn phí, tạo trong 1 phút). Dùng chung cho Airflow và GitHub Actions | Đáp ứng "notifications" ở Phần 3 và Phần 4 |
| D6 | **Rollback** | Mỗi lần deploy prod thành công → gắn **git tag** `prod-YYYYMMDD-HHMM`. Trước khi deploy → **backup mọi bảng trong schema gold**. Deploy lỗi → khôi phục backup. Có thêm workflow rollback chạy tay | Đáp ứng "rollback capability" + "deployment history" |
| D7 | **Repo và bảo vệ nhánh** | Repo **public**. `main`, `develop`: **bắt buộc Pull Request**, **0 người duyệt** (làm một mình, GitHub không cho tự duyệt PR của mình), **bắt buộc CI xanh** (bật ở `03`). Prod cần duyệt thủ công qua **GitHub Environments** (bạn tự duyệt, được phép) | CI đóng vai "người review"; vẫn có lịch sử PR để chấm điểm |
| D8 | **Lint** | Python: `flake8` + `black`; SQL: `sqlfluff` (dialect `tsql`, templater `jinja`, chỉ `dbt/models/`); chạy ở **pre-commit** (local) và **CI** với cùng cấu hình | Đúng yêu cầu Phần 4A |
| D9 | **Chọn model theo tầng** | Airflow và CI chọn model theo **thư mục**: `--select path:models/bronze`, `path:models/silver`, `path:models/gold` | Thêm/đổi tên model không phải sửa DAG |
| D10 | **Biến môi trường cho container** | Mọi biến cho dbt và Airflow (`DBT_*`, `NOTIFY_WEBHOOK_URL`, `AIRFLOW_VAR_DBT_TARGET`, `AIRFLOW_CONN_MSSQL_DEFAULT`) **đã khai báo sẵn** trong `docker-compose.yml` ở `02` | Các file sau chỉ cần điền `.env`, không phải sửa `docker-compose.yml` |
| D11 | **Health check & backup không phụ thuộc tên bảng** | Kiểm tra/backup **mọi bảng trong một schema** (vd. `prod_gold`), không liệt kê tên bảng cố định | Đổi tên model ở `04` không làm hỏng workflow ở `07`, `08` |

---

## 6. Danh sách công việc chi tiết (theo phần chấm điểm)

Ký hiệu: **[MVP]** = bắt buộc để qua môn · **[FULL]** = cần cho điểm tối đa · **[BONUS]**.

### Phần 1 — dbt Data Models (25đ) · file `04`

**Bronze (8đ)** — [MVP: ≥2 model] [FULL: ≥3 bảng nguồn, làm sạch, freshness, mô tả mọi cột]
- 1 model bronze = 1 bảng nguồn, materialized `view`. Dự kiến 7 model:
  `brnz_customer`, `brnz_person`, `brnz_sales_order_header`, `brnz_sales_order_detail`, `brnz_product`, `brnz_product_subcategory`, `brnz_product_category`.
- Làm sạch: đổi tên cột sang `snake_case`, `cast` kiểu dữ liệu, `trim` chuỗi, chuẩn hóa NULL. **Không join** ở bronze.
- Gộp source vào 1 file `_sources.yml`, khai báo `loaded_at_field` + `freshness`.
- Mô tả **mọi cột** trong `_bronze__models.yml`.

**Silver (8đ)** — [FULL: ≥2 model, join nhiều bronze, logic nghiệp vụ, có test]
- `slvr_customers` = customer + person; `slvr_products` = product + subcategory + category; `slvr_sales_orders` = order header + detail.
- **Giữ nguyên tên cột đầu ra** của silver hiện tại → gold không bị vỡ khi tách bronze.

**Gold (9đ)** — [MVP: ≥1 model] [FULL: ≥2 model, aggregation, tối ưu hiệu năng]
- **Sửa lỗi logic** 3 model hiện có; *(khuyến nghị)* thêm `gld_customer_segments` (RFM) hoặc `gld_monthly_sales`.
- **Hiệu năng (3đ):** `slvr_sales_orders` (~121 nghìn dòng) chuyển sang `incremental`; index qua `post_hook`; **đo thời gian trước/sau**, ghi vào `docs/PERFORMANCE.md`.

**Tài liệu:** mọi model/cột có `description`; dùng `{% docs %}` cho mô tả dài.

### Phần 2 — Automated Testing (20đ) · file `05`

- **Schema tests (8đ)** [MVP: `not_null` + `unique` khóa chính]: thêm `relationships` (khóa ngoại), `accepted_values` (`status` ∈ 1..6, `order_channel`, các cờ 0/1), `dbt_utils.unique_combination_of_columns`.
- **Custom tests (7đ)** [FULL: ≥3 generic test tự viết] trong `dbt/tests/generic/`: `positive_value`, `valid_date_range`, `date_not_before`, `row_count_greater_than`. Thêm singular tests nghiệp vụ (tổng doanh thu gold = silver...). Dùng `severity: warn/error`, `store_failures`.
- **Source freshness (5đ)**: `loaded_at_field: ModifiedDate`, `warn_after: 24h`, `error_after: 48h`, ghi độ trễ kỳ vọng. Script `scripts/simulate_new_data.sql` cập nhật `ModifiedDate = GETDATE()` để freshness có thể PASS khi demo.
- **Tài liệu:** `docs/TESTING.md`.

### Phần 3 — Airflow Orchestration (15đ) · file `06`

Viết lại `airflow/dags/dbt_dag.py` thành DAG `dbt_pipeline`:

```
check_sqlserver ─► dbt_deps ─► source_freshness
   ─► [bronze: run ─► test] ─► [silver: run ─► test] ─► [gold: run ─► test]
   ─► data_quality_checks ─► dbt_docs_generate ─► notify_success
```

- `schedule="@daily"`, `catchup=False`; `retries=2`, `retry_delay`, `retry_exponential_backoff`, `execution_timeout`.
- `on_failure_callback` → Discord (URL lấy từ biến `NOTIFY_WEBHOOK_URL`, không ghi trong code).
- `data_quality_checks` bằng `SQLCheckOperator` qua connection `mssql_default` (đã khai báo ở `02`).
- Chọn môi trường qua Variable `dbt_target`; tài liệu `doc_md`; `tests/test_dag_integrity.py` (pytest) để CI chạy.

### Phần 4 — CI/CD & Deployment Automation (35đ) · file `03`, `07`, `08`

| Hạng mục | Nội dung | File |
|---|---|---|
| **4A. CI (10đ)** | `ci.yml` trên mọi PR: black, flake8, sqlfluff, pytest DAG, `dbt compile` + `dbt build --target ci` + docs trên SQL Server dựng trong runner. `pr-validation.yml`: tiêu đề PR theo Conventional Commits, chặn file > 5 MB, kiểm tra conflict. **Bật CI bắt buộc** trong bảo vệ nhánh | `03` |
| **4B. CD cơ bản (12đ)** [MVP] | `deploy.yml`: merge vào `develop`/`main` → `dbt deps` → `dbt run` → `dbt test`, trạng thái xanh/đỏ, upload log | `03` |
| **4B. CD nâng cao (8đ)** | Theo môi trường (`develop → dev`; `main → staging → duyệt → prod`), pre-deploy validation, post-deploy health check, thông báo Discord + Job Summary, badges, tag `prod-*` | `07` |
| **4C. Tài liệu & giám sát (5đ)** | Backup + rollback tự động, `rollback.yml` (chạy tay), `deploy-report.yml` (tỉ lệ thành công), `DEPLOYMENT_RUNBOOK.md`, `ROLLBACK.md` | `08` |

### Phần 5 — Documentation & Presentation (5đ) · file `03`, `09`

- `03`: **README tối thiểu** (tổng quan, cài đặt, cách chạy, troubleshooting cơ bản) → đủ điều kiện MVP.
- `09`: README hoàn chỉnh (badges, sơ đồ, khai báo dùng AI), `docs/ARCHITECTURE.md` + ảnh sơ đồ, `docs/SETUP_GUIDE.md` (người mới cài < 30 phút), `docs/TROUBLESHOOTING.md`, `docs/DEMO_SCRIPT.md` (kịch bản demo trực tiếp 15 phút).

### Bonus

| Bonus | Nội dung | File |
|---|---|---|
| **4 – Multi-env** | Thêm **staging** giữa dev và prod; GitHub Environments `dev`, `staging`, `production` (prod cần duyệt) | `07` |
| **1 – Grafana** | `docker-compose.monitoring.yml` (không sửa compose gốc); datasource Postgres (metadata Airflow) + SQL Server; dashboard dạng code (provisioning) | `10` |
| **2 – Lineage** | `dbt docs generate` → **GitHub Pages** tự động; `exposures.yml` khai báo nơi dùng dữ liệu | `11` |

---

## 7. Cấu trúc thư mục mục tiêu

```
dbt_airflow_project/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # 03 – CI cho Pull Request
│   │   ├── pr-validation.yml         # 03 – kiểm tra PR
│   │   ├── deploy.yml                # 03 (cơ bản) → 07 (dev/staging/prod)
│   │   ├── rollback.yml              # 08 – rollback thủ công
│   │   ├── deploy-report.yml         # 08 – thống kê deployment
│   │   └── docs-pages.yml            # 11 – lineage lên GitHub Pages
│   └── pull_request_template.md      # 02 ✅
├── airflow/dags/
│   ├── dbt_dag.py                    # 06 – DAG dbt_pipeline
│   └── utils/notifications.py        # 06 – gửi Discord
├── dbt/
│   ├── models/{bronze,silver,gold}/  # 04
│   ├── models/docs.md                # 04 – doc blocks
│   ├── models/exposures.yml          # 11
│   ├── tests/generic/, tests/*.sql   # 05
│   ├── macros/generate_schema_name.sql   # 02 ✅
│   └── profiles.yml                  # 02 ✅ (env_var, 4 target)
├── scripts/
│   ├── init_sqlserver.sh             # 02 ✅
│   ├── health_check.sql              # 07
│   └── simulate_new_data.sql         # 05
├── monitoring/grafana/provisioning/  # 10
├── tests/test_dag_integrity.py       # 06
├── docs/                             # 05, 08, 09: TESTING, PERFORMANCE, DEPLOYMENT_RUNBOOK, ROLLBACK,
│                                     #             ARCHITECTURE, SETUP_GUIDE, TROUBLESHOOTING, DEMO_SCRIPT
├── project/                          # các file hướng dẫn này
├── docker-compose.yml                # 02 ✅
├── docker-compose.ci.yml             # 03
├── docker-compose.monitoring.yml     # 10
├── .env.example, .pre-commit-config.yaml, .sqlfluff, .flake8, pyproject.toml   # 02 ✅
└── README.md                         # 03 (tối thiểu) → 09 (đầy đủ)
```

---

## 8. Quy trình làm việc với Git

Dù làm một mình, **mọi thay đổi vẫn đi qua Pull Request**. Lý do: đề bài chấm "tests run automatically on pull requests", "PR validation", "proper branch structure". CI đóng vai người review.

```
develop ──┬────────────────────────────────────────────┬──► (phát hành) ──► main
          │                                            ▲
          └─► feature/ten-viec ──► Pull Request ──► CI xanh ──► Squash and merge
```

1. Luôn tạo nhánh từ `develop`: `git switch develop && git pull && git switch -c feature/bronze-refactor`.
2. Commit theo **Conventional Commits** (pre-commit tự chặn nếu sai): `feat:`, `fix:`, `test:`, `docs:`, `ci:`, `refactor:`, `perf:`, `style:`, `build:`, `chore:`.
3. `git push -u origin <nhánh>` → `gh pr create --base develop --fill` (tiêu đề PR cũng theo Conventional Commits).
4. Đợi CI xanh → **Squash and merge** (tự merge, không cần người duyệt).
5. **Phát hành:** PR `develop → main`, merge bằng **Create a merge commit** (không squash, để `main` và `develop` không lệch nhau).
6. PR nhỏ, mỗi PR một việc → dễ đọc lịch sử, dễ rollback.

**Quy ước đặt tên:**

| Thứ | Quy ước |
|---|---|
| Nhánh | `feature/...`, `fix/...`, `docs/...`, `ci/...` |
| Model | `brnz_<bảng>`, `slvr_<thực thể>`, `gld_<chủ đề>`; cột `snake_case` |
| File YAML dbt | `_sources.yml`, `_bronze__models.yml`, `_silver__models.yml`, `_gold__models.yml` |
| Target dbt | `dev`, `staging`, `prod`, `ci` |
| GitHub Secrets | `SA_PASSWORD`, `DBT_ENV_SECRET_PASSWORD`, `NOTIFY_WEBHOOK_URL` |
| Tag phát hành | `prod-YYYYMMDD-HHMM` |

---

## 9. Lộ trình các file hướng dẫn

Làm **đúng theo thứ tự số**. Mỗi file kết thúc bằng checklist; xong checklist mới sang file sau.

| File | Nội dung | Điểm liên quan | Ước lượng | Mốc |
|---|---|---|---|---|
| `01_CHUAN_BI_MOI_TRUONG.md` | Công cụ, Docker, chạy hệ thống trên máy | — | ✅ xong | |
| `02_GIT_GITHUB_VA_NEN_TANG.md` | Repo, nhánh, `.env`, compose, pre-commit | — | ✅ xong | |
| `03_CI_VA_DEPLOY_CO_BAN.md` | SQL Server trong GitHub Actions, `ci.yml`, `pr-validation.yml`, `deploy.yml` cơ bản, bật CI bắt buộc, README tối thiểu | 4A + 4B cơ bản + 5 | 6–8 giờ | 🥉 **MVP** |
| `04_DBT_MODELS.md` | Tách bronze, silver, sửa gold, model mới, hiệu năng, tài liệu | Phần 1 | 8–10 giờ | |
| `05_DBT_TESTING.md` | Schema, custom, singular tests, freshness | Phần 2 | 6–8 giờ | |
| `06_AIRFLOW_DAG.md` | DAG theo tầng, retry, SQL check, Discord, DAG test | Phần 3 | 5–7 giờ | |
| `07_CD_VA_MULTI_ENV.md` | dev/staging/prod, duyệt prod, pre/post check, thông báo, tag, badges | 4B nâng cao + Bonus 4 | 6–8 giờ | |
| `08_ROLLBACK_VA_GIAM_SAT_DEPLOY.md` | Backup/rollback, rollback thủ công, thống kê deploy, runbook | 4C | 4–6 giờ | |
| `09_TAI_LIEU_VA_DEMO.md` | README đầy đủ, kiến trúc, setup guide, troubleshooting, kịch bản demo | Phần 5 | 4–6 giờ | 🥈 **100 điểm** |
| `10_GRAFANA_MONITORING.md` | Grafana + dashboard | Bonus 1 | 4–6 giờ | 🥇 |
| `11_LINEAGE_GITHUB_PAGES.md` | dbt docs + lineage lên GitHub Pages, exposures | Bonus 2 | 2–3 giờ | 🥇 |

**Tổng còn lại:** khoảng 45–60 giờ.

---

## 10. Kế hoạch 3 tuần

| Tuần | Việc | Mốc cuối tuần |
|---|---|---|
| **Tuần 1** | `03` (CI + deploy cơ bản + README tối thiểu) → `04` (dbt models) | ✅ **Qua môn (~60đ)**; model đã chuẩn hóa |
| **Tuần 2** | `05` (testing) → `06` (Airflow) → `07` (CD nâng cao + multi-env) | Phần 1, 2, 3 và phần lớn Phần 4 xong |
| **Tuần 3** | `08` (rollback) → `09` (tài liệu + demo) → `10`, `11` (bonus) → **tập demo 2 lần** | ✅ **~100đ + bonus** |

**Nếu thiếu thời gian**, bỏ theo thứ tự (bỏ cái đầu tiên trước):
1. Bonus 2 – lineage (`11`)
2. Bonus 1 – Grafana (`10`)
3. Môi trường staging (vẫn giữ dev + prod, vì "dev vs prod" là yêu cầu bắt buộc)
4. Model gold thứ 4, bảng kết quả test dbt trong Grafana

**Không bao giờ bỏ:** CI, deploy, test, DAG, README.

### Kịch bản demo trực tiếp 15 phút

1. (2') Giới thiệu bài toán + kiến trúc.
2. (3') Tạo PR sửa một model → CI chạy: lint, test, kiểm tra PR.
3. (3') Merge → deploy dev → merge `main` → staging → duyệt → prod; thông báo về Discord.
4. (2') Airflow UI: DAG theo tầng, xem log, minh họa retry/lỗi.
5. (2') Grafana dashboard + trang lineage trên GitHub Pages.
6. (1') Minh họa rollback.
7. (2') Khó khăn & bài học.

---

## 11. Checklist nộp bài + rủi ro

### 11.1. Checklist nộp bài (đối chiếu đề bài)

- [ ] Repo GitHub có `main`, `develop`, các nhánh `feature/*`; commit theo Conventional Commits
- [ ] ≥3 bronze, ≥2 silver, ≥2 gold; `dbt build` thành công
- [ ] Mọi model/cột có mô tả; lineage xem được
- [ ] not_null, unique, relationships, accepted_values; ≥3 custom generic tests; freshness cho mọi source
- [ ] DAG daily, phụ thuộc đúng thứ tự, retry, kiểm tra chất lượng, thông báo lỗi, có tài liệu
- [ ] CI: compile + test dbt, flake8, black, sqlfluff, kiểm tra PR, sinh docs
- [ ] CD: merge `develop`/`main` → deps/run/test tự động, có log, xanh/đỏ rõ ràng
- [ ] dev/staging/prod, thông báo, badges, rollback, pre-check, health check
- [ ] Runbook, lịch sử deployment, tỉ lệ thành công, quy trình rollback
- [ ] README, sơ đồ kiến trúc (ảnh), SETUP_GUIDE, TROUBLESHOOTING, tài liệu model
- [ ] Demo trực tiếp 15 phút (đã tập ít nhất 2 lần)
- [ ] Bonus: Grafana, lineage trên Pages, multi-env
- [ ] README ghi rõ: dự án do một người thực hiện + khai báo có dùng công cụ AI (đề bài yêu cầu)

### 11.2. Rủi ro và cách phòng tránh

| Rủi ro | Phòng tránh |
|---|---|
| **Không đủ thời gian** (một người làm việc của ba người) | Làm đúng thứ tự mốc; MVP xong tuần 1; danh sách "bỏ gì trước" ở mục 10 |
| Dựng SQL Server trong CI chậm/lỗi (bước khó nhất) | Làm ngay ở `03`; dùng chung `scripts/init_sqlserver.sh`; `docker compose up --wait` thay vì `sleep` |
| Freshness luôn lỗi do dữ liệu cũ | Script `simulate_new_data.sql` (file `05`) |
| Lộ mật khẩu / webhook lên repo public | `.env` trong `.gitignore`; pre-commit `detect-private-key`; chỉ dùng GitHub Secrets |
| Chỉ có một máy, máy hỏng trước buổi demo | Push thường xuyên; `docs/SETUP_GUIDE.md` để cài lại trên máy khác trong 30 phút |
| Máy yếu RAM khi chạy đủ dịch vụ + Grafana | Chỉ bật Grafana khi cần (`docker-compose.monitoring.yml` riêng) |
| Vi phạm liêm chính học thuật | Hiểu được mọi dòng code mình nộp; khai báo việc dùng AI trong README |
