# Đối chiếu yêu cầu đề bài (traceability matrix)

Mỗi yêu cầu trong [`docs/course/4. DATAOPS_PROJECT_REQUIREMENTS.md`](course/4.%20DATAOPS_PROJECT_REQUIREMENTS.md) → nơi đáp ứng → cách kiểm chứng.

**Ký hiệu kiểm chứng** (ngày 2026-11-13):
- 🟢 **Đã chạy thật** trên hệ thống local (SQL Server, Airflow 2.7.1, Grafana) hoặc trên stack Docker mô phỏng CI/CD.
- 🔵 **Kiểm tra tĩnh** (lint, schema, parse).
- 🟡 **Kiểm chứng trên GitHub** sau khi push (workflow, Environments, Pages) — hướng dẫn ở `project/03`, `06`, `07`, `10`.

---

## Phần 1 — dbt Data Models (25đ)

| Yêu cầu | Đáp ứng | Kiểm chứng |
|---|---|---|
| Bronze: lấy ≥ 3 bảng nguồn | 7 model `brnz_*` từ 7 bảng (`dbt/models/bronze/`) | 🟢 `dbt build` |
| Bronze: làm sạch, chuẩn hóa | snake_case, `cast`, `trim`, `nullif`, bỏ cột XML | 🟢 test `accepted_values` trên cột đã trim |
| Bronze: source freshness | `_sources.yml`: `loaded_at_field`, warn 24h, error 48h | 🟢 ERROR STALE → mô phỏng → PASS |
| Bronze: mô tả mọi cột | `_bronze__models.yml` | 🔵 kiểm tra manifest: 0 cột thiếu mô tả |
| Silver: ≥ 2 model trung gian | `slvr_customers`, `slvr_products`, `slvr_sales_orders` | 🟢 |
| Silver: logic nghiệp vụ, join nhiều bronze | loại khách, phân khúc giá, kênh bán, trạng thái; join 2–3 bronze | 🟢 |
| Silver: có test | 30+ test ở `_silver__models.yml` | 🟢 |
| Gold: ≥ 2 mart | 4 model `gld_*` | 🟢 |
| Gold: aggregation và metrics | doanh số/ngày, chỉ số khách, hiệu quả sản phẩm, RFM | 🟢 3 singular test đối soát pass |
| Gold: tối ưu hiệu năng | table + clustered columnstore; incremental + index ở silver | 🟢 benchmark: `docs/PERFORMANCE.md` |
| Tài liệu model + lineage | mô tả YAML, `docs.md`, `dbt docs`, `exposures.yml`, `docs/LINEAGE.md` | 🟢 `dbt docs generate`; 🟡 GitHub Pages |
| Đúng SQL, phân tầng, tài liệu, hiệu năng (tiêu chí) | sửa 3 lỗi logic gold; bronze không join | 🟢 `PASS=157` |

## Phần 2 — Automated Testing (20đ)

| Yêu cầu | Đáp ứng | Kiểm chứng |
|---|---|---|
| `not_null` khóa chính | 50 test | 🟢 |
| `unique` định danh | 26 test | 🟢 |
| `relationships` khóa ngoại | 11 test | 🟢 |
| `accepted_values` | 19 test | 🟢 |
| ≥ 3 custom generic test | `positive_value`, `valid_date_range`, `date_not_before`, `row_count_greater_than` | 🟢 + diễn tập thất bại có chủ đích |
| Test logic nghiệp vụ | 3 singular test đối soát; `expression_is_true` | 🟢 |
| Kiểm tra giá trị dương, khoảng ngày | `positive_value`, `valid_date_range`, `date_not_before` | 🟢 |
| Freshness cho mọi nguồn, ngưỡng warn/error, độ trễ kỳ vọng | 7/7 bảng, `meta.expected_latency` | 🟢 |
| Tài liệu test | `docs/TESTING.md` | 🔵 |

## Phần 3 — Airflow Orchestration (15đ)

| Yêu cầu | Đáp ứng | Kiểm chứng |
|---|---|---|
| DAG chạy model đúng thứ tự | `dbt_pipeline`: bronze → silver → gold, test sau mỗi tầng | 🟢 chạy trọn 14 task; pytest kiểm tra 12 cặp thứ tự |
| Phụ thuộc giữa task | TaskGroup, `>>` | 🟢 pytest 18/18 trên Airflow 2.7.1 |
| Lịch daily/hourly | `@daily`, `catchup=False` | 🟢 lần chạy `scheduled__` tự tạo |
| Error handling + retry | 2 retry tăng dần, timeout task/DAG | 🟢 diễn tập: lần 1 lỗi, retry thành công |
| Data quality checks trong pipeline | freshness, `dbt test` từng tầng, singular tests, 2 `SQLCheckOperator` | 🟢 |
| Thông báo khi lỗi | Discord: task lỗi, retry, DAG thành công | 🟢 payload kiểm tra bằng HTTP server giả; 🟡 Discord thật khi có webhook |
| Tài liệu DAG | `doc_md` cho DAG và task | 🔵 |

## Phần 4 — CI/CD & Deployment Automation (35đ)

| Yêu cầu | Đáp ứng | Kiểm chứng |
|---|---|---|
| **A.** dbt compilation workflow | `ci.yml` → `dbt compile` | 🟢 mô phỏng; 🟡 GitHub |
| **A.** dbt test trên PR | `ci.yml` → `dbt build` (target `ci`) | 🟢 mô phỏng `PASS=157`; 🟡 |
| **A.** flake8, black | job `lint` (pre-commit) | 🔵 |
| **A.** sqlfluff | job `lint` | 🔵 |
| **A.** Code quality checks (bổ sung) | SonarCloud Quality Gate trên mọi PR; `pip install` khóa phiên bản + chỉ dùng wheel | 🟡 SonarCloud trên PR |
| **A.** PR validation (tiêu đề, file size, conflict) | `pr-validation.yml` (+ tên nhánh) | 🔵 actionlint; 🟡 |
| **A.** Sinh tài liệu tự động | `dbt docs generate` + artifact | 🟢 mô phỏng |
| **B.** Trigger khi merge `develop`/`main` | `deploy.yml` | 🔵; 🟡 |
| **B.** `dbt deps` / `run` / `test` tự động | `_deploy.yml` + composite action | 🟢 mô phỏng |
| **B.** Trạng thái xanh/đỏ, log deploy | Job Summary, artifact `deploy-logs-<env>` | 🟢 `dbt_summary.py`; 🟡 |
| **B.** Deploy theo môi trường (dev vs prod) | dev / staging / production, target + schema + secret riêng | 🟢 target `ci`/`prod` mô phỏng; 🟡 Environments |
| **B.** Thông báo deploy | `notify.py` → Job Summary + Discord | 🟢 |
| **B.** Badges | README | 🟡 |
| **B.** Rollback | tự động (backup → restore) + thủ công (`rollback.yml`) | 🟢 mô phỏng rollback về đúng bản cũ; 🟡 `rollback.yml` |
| **B.** Pre-deployment validation | `dbt debug/parse/compile` | 🟢 mô phỏng |
| **B.** Post-deployment health check | macro `health_check` | 🟢 phát hiện bảng rỗng → mã lỗi |
| **C.** Tài liệu quy trình deploy trong README | mục CI/CD của README + `DEPLOYMENT_RUNBOOK.md` | 🔵 |
| **C.** Runbook | `docs/DEPLOYMENT_RUNBOOK.md` | 🔵 |
| **C.** Theo dõi lịch sử deploy | tag `prod-*`, tab Deployments | 🟢 tag (cục bộ); 🟡 |
| **C.** Theo dõi tỉ lệ thành công | `deploy-report.yml` + `deploy_report.py` | 🔵 chạy thử script; 🟡 |
| **C.** Tài liệu rollback | `docs/ROLLBACK.md` | 🔵 |

## Phần 5 — Documentation & Presentation (5đ)

| Yêu cầu | Đáp ứng | Kiểm chứng |
|---|---|---|
| README: tổng quan + cài đặt | `README.md` | 🔵 |
| Sơ đồ kiến trúc | `docs/images/architecture.svg` (+ Mermaid trong `ARCHITECTURE.md`) | 🔵 render thử |
| Setup guide cho người mới | `docs/SETUP_GUIDE.md` | 🟢 các bước cài đặt đã chạy trên database mới (mô phỏng CI) |
| Troubleshooting | `docs/TROUBLESHOOTING.md` | 🔵 gồm các lỗi gặp khi chạy thử |
| Demo 15 phút | `docs/DEMO_SCRIPT.md` | — tập trước buổi demo |

## Yêu cầu nộp bài

| Yêu cầu | Đáp ứng |
|---|---|
| Nhánh `main`, `develop`, feature | quy trình trong `project/02`–`10` |
| Conventional Commits | pre-commit `conventional-pre-commit` + kiểm tra tiêu đề PR |
| Sơ đồ kiến trúc (PDF/ảnh), setup guide, tài liệu model, troubleshooting | `docs/` |
| Khai báo dùng AI | mục cuối `README.md` |

## Bonus

| Bonus | Đáp ứng | Kiểm chứng |
|---|---|---|
| Monitoring dashboard | Grafana dạng code (`docker-compose.monitoring.yml`, `monitoring/grafana/`) | 🟢 11/11 panel có dữ liệu |
| Data lineage visualization | dbt docs trên GitHub Pages + `docs/LINEAGE.md` + exposures | 🟢 sinh tài liệu; 🟡 Pages |
| Multi-environment dev/staging/prod | GitHub Environments + target/schema riêng | 🟡 |
