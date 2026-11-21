# 03 — CI VÀ DEPLOY CƠ BẢN (đạt MVP)

| | |
|---|---|
| **Phần chấm điểm** | Phần 4A — CI (10đ), Phần 4B — CD cơ bản (12đ), Phần 5 — README (một phần) |
| **Thời gian** | 4–6 giờ (phần lớn là chờ GitHub Actions chạy) |
| **Điều kiện** | Đã xong [`01`](01_CHUAN_BI_MOI_TRUONG.md), [`02`](02_GIT_GITHUB_VA_NEN_TANG.md) |
| **Kết quả** | Mọi Pull Request được kiểm tra tự động; merge vào `develop` → tự deploy **dev**; merge vào `main` → tự deploy **staging → production** + tag phiên bản. **Đạt mốc MVP (~60 điểm)** |

> 📦 **Tất cả file của dự án (cho file 03 → 10) đã được tạo sẵn trong thư mục dự án.** Mỗi file hướng dẫn giải thích các file của bước đó và chỉ cách **commit đúng các file đó** theo từng bước.
> Vì vậy trong thư mục đang có cả file của các bước sau (model dbt mới, DAG mới, Grafana...). **Chỉ `git add` đúng đường dẫn được liệt kê**, không dùng `git add -A` / `git add .`.

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 0 — Hoàn tất PR #1 và lưu các file hướng dẫn](#bước-0--hoàn-tất-pr-1-và-lưu-các-file-hướng-dẫn)
- [Bước 1 — Dựng SQL Server trên GitHub Actions](#bước-1--dựng-sql-server-trên-github-actions)
- [Bước 2 — Workflow CI](#bước-2--workflow-ci)
- [Bước 3 — Workflow kiểm tra Pull Request](#bước-3--workflow-kiểm-tra-pull-request)
- [Bước 4 — Macro vận hành (health check, backup, restore)](#bước-4--macro-vận-hành-health-check-backup-restore)
- [Bước 5 — Workflow deploy](#bước-5--workflow-deploy)
- [Bước 6 — README](#bước-6--readme)
- [Bước 7 — Commit và mở Pull Request](#bước-7--commit-và-mở-pull-request)
  - [7.6 — SonarCloud](#76-sonarcloud-nếu-repo-có-kết-nối)
- [Bước 8 — Bật CI bắt buộc](#bước-8--bật-ci-bắt-buộc)
- [Bước 9 — Kiểm tra deploy dev tự động](#bước-9--kiểm-tra-deploy-dev-tự-động)
- [Bước 10 — Phát hành lần đầu lên main](#bước-10--phát-hành-lần-đầu-lên-main)
- [Checklist hoàn thành (mốc MVP)](#checklist-hoàn-thành-mốc-mvp)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Nội dung | Mục đích |
|---|---|---|
| `.github/actions/setup-dbt-stack/action.yml` | Composite action 5 bước: tạo `.env` tạm → build image → khởi động SQL Server + dbt → restore AdventureWorks → `dbt deps` | Dùng chung cho CI và CD, không lặp code |
| `scripts/ci/create_env.sh` | Sinh file `.env` cho máy ảo GitHub; mật khẩu lấy từ Secrets hoặc sinh ngẫu nhiên, được che trong log | Máy ảo không có `.env` của bạn (và không được có) |
| `scripts/ci/dbt.sh` | Chạy 1 lệnh dbt trong container, lưu `run_results.json` với nhãn riêng (`run_results_build.json`...) | Giữ kết quả từng lệnh để tóm tắt |
| `scripts/ci/dbt_summary.py` | Đọc các `run_results_*.json` → bảng số model/test thành công/lỗi + chi tiết lỗi → **Job Summary** | Đọc kết quả ngay trên trang GitHub, không phải lục log |
| `.github/workflows/ci.yml` | 3 job song song: `lint`, `dag-tests`, `dbt-build` | **Phần 4A**: CI cho mọi Pull Request |
| `.github/requirements/lint-constraints.txt` | Khóa phiên bản pre-commit 4.7.0 và 10 gói phụ thuộc của nó | Job `lint` cài đúng các phiên bản này (an toàn chuỗi cung ứng; đạt yêu cầu bảo mật của SonarCloud) |
| `.github/workflows/pr-validation.yml` | Job `validate-pr`: tiêu đề PR, tên nhánh, file > 5 MB, xung đột | **Phần 4A**: "Pull request validation" |
| `dbt/macros/ops/_ops_helpers.sql` | 3 macro nhỏ: tên schema của tầng, liệt kê bảng/view, đếm dòng | Dùng chung cho các macro vận hành |
| `dbt/macros/ops/health_check.sql` | Kiểm tra mọi bảng/view của các tầng tồn tại và có dữ liệu | **Post-deploy health check** |
| `dbt/macros/ops/backup_layers.sql` | Sao chép bảng silver/gold sang schema `*__backup` | Backup trước deploy (giải thích kỹ ở file 07) |
| `dbt/macros/ops/restore_layers.sql` | Khôi phục bảng từ backup | Rollback tự động (file 07) |
| `dbt/macros/ops/drop_orphan_relations.sql` | Liệt kê / xóa bảng/view không còn model tương ứng | Dọn dẹp sau khi đổi tên model (dùng ở file 04) |
| `.github/workflows/deploy.yml` | Kích hoạt deploy: `develop` → dev; `main` → staging → production | **Phần 4B**: deploy tự động khi merge |
| `.github/workflows/_deploy.yml` | Workflow dùng chung chứa toàn bộ các bước của **một** lần deploy | Dùng lại cho deploy và rollback |
| `scripts/ci/deploy_baseline.sh` | Dựng lại phiên bản production đang chạy (tag `prod-*`) trong database tạm | Để backup/rollback có ý nghĩa (file 07) |
| `scripts/ci/notify.py` | Ghi kết quả deploy vào Job Summary + gửi Discord (nếu có webhook) | Thông báo deploy (kích hoạt Discord ở file 06) |
| `README.md` | Trang giới thiệu dự án: badges, kiến trúc, cài đặt, chạy, CI/CD, troubleshooting, khai báo AI | **Phần 5**: README (MVP) |
| `scripts/init_sqlserver.sh` | **Sửa** (file từ file 02): thử lại RESTORE tối đa 3 lần + kiểm tra database ONLINE; in rõ dòng lỗi thay vì thoát im lặng; output của `docker compose exec` luôn đi qua pipe | Đã chạy thử trên database **mới hoàn toàn** (giống CI): bản cũ có thể thoát im lặng khi Docker cài bằng snap và output bị ghi ra file |

**Kế hoạch commit** (nhánh `ci/github-actions`, 1 Pull Request):

| # | Commit message | File |
|---|---|---|
| 0 | `fix(scripts): make SQL Server init script robust for CI` | `scripts/init_sqlserver.sh` |
| 1 | `ci: add reusable action to provision SQL Server and dbt` | action + `create_env.sh`, `dbt.sh`, `dbt_summary.py` |
| 2 | `ci: add CI workflow for pull requests` | `ci.yml`, `lint-constraints.txt` |
| 3 | `ci: add pull request validation workflow` | `pr-validation.yml` |
| 4 | `feat(dbt): add operational macros for health check, backup and restore` | `dbt/macros/ops/` (trừ `simulate_new_data.sql`) |
| 5 | `ci: add deployment workflows for dev, staging and production` | `deploy.yml`, `_deploy.yml`, `deploy_baseline.sh`, `notify.py` |
| 6 | `docs: add project README` | `README.md` |

---

## Bước 0 — Hoàn tất PR #1 và lưu các file hướng dẫn

Pull Request #1 (đơn giản hóa bảo vệ nhánh, bỏ `CODEOWNERS`) vẫn đang mở vì nhánh còn yêu cầu 1 người duyệt.

### 0.1. Sửa bảo vệ nhánh (0 người duyệt)

```bash
cd ~/HCMUS/Advanced_DevOps/DataOps/dbt_airflow_project
for BRANCH in main develop; do
gh api -X PUT "repos/{owner}/{repo}/branches/$BRANCH/protection" --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
done

# Kiểm tra: phải in "0 approvals" hai lần
for b in main develop; do gh api "repos/{owner}/{repo}/branches/$b/protection" --jq '"\(.required_pull_request_reviews.required_approving_review_count) approvals"'; done
```

### 0.2. Thêm các file hướng dẫn vào PR #1 rồi merge

Thư mục dự án đang ở nhánh của PR #1.

```bash
git branch --show-current                     # nhánh của PR #1
git add project/ .env.example
git status --short project/ .env.example      # chỉ thấy file hướng dẫn + .env.example (KHÔNG có .env)
git commit -m "docs: add step-by-step guides 03 to 10"
# Nếu pre-commit báo "files were modified by this hook": chạy lại 2 lệnh git add + git commit ở trên
git push

gh pr merge 1 --squash --delete-branch
git switch develop
git pull
git log --oneline -3                          # commit mới nhất là commit của PR #1
```

> 📝 `.env.example` đổi 2 chỗ: thêm biến `GRAFANA_ADMIN_PASSWORD` (dùng ở file 09) và sửa chú thích webhook. File `.env` của bạn không bị ảnh hưởng.

Kiểm tra trạng thái: `git status` vẫn còn **nhiều file chưa commit** (thuộc file 03 → 10). Đó là bình thường.

---

## Bước 1 — Dựng SQL Server trên GitHub Actions

**Vấn đề:** CI cần chạy `dbt build` trên database thật, nhưng máy ảo của GitHub **không** kết nối được SQL Server trên laptop.

**Giải pháp (quyết định D2):** mỗi lần chạy, dựng một SQL Server **tạm** trên máy ảo bằng **chính `docker-compose.yml` của dự án**. Khi job kết thúc, máy ảo bị xóa cùng database.

`.github/actions/setup-dbt-stack/action.yml` gồm 5 bước:

| Bước | Lệnh | Giải thích |
|---|---|---|
| 1 | `./scripts/ci/create_env.sh <target>` | Tạo `.env` tạm. Mật khẩu: lấy từ GitHub Secrets `SA_PASSWORD` / `DBT_ENV_SECRET_PASSWORD` nếu có, không thì **sinh ngẫu nhiên** (`Gh` + 24 ký tự hex + `X9` → đủ chữ hoa, chữ thường, số). Mọi giá trị được `::add-mask::` → hiện `***` trong log |
| 2 | `docker compose build sqlserver dbt` | Build đúng 2 image cần dùng (không build Airflow) |
| 3 | `docker compose up -d --wait sqlserver dbt` | `--wait` chờ tới khi SQL Server **healthy** (nhờ healthcheck đã thêm ở file 02) |
| 4 | `./scripts/init_sqlserver.sh` | **Cùng script** bạn dùng ở máy local: restore AdventureWorks + tạo `dbt_user` |
| 5 | `docker compose exec -T dbt dbt deps` | Cài `dbt_utils` (`-T` = không cần terminal, bắt buộc trên CI) |

Hai script phụ:
- **`scripts/ci/dbt.sh <nhãn> <lệnh dbt>`**: mỗi lệnh dbt ghi đè `target/run_results.json`, nên script chép kết quả sang `run_results_<nhãn>.json` ngay sau lệnh và giữ nguyên mã thoát của dbt.
- **`scripts/ci/dbt_summary.py "<tiêu đề>"`**: gộp các file đó thành bảng trên trang **Summary** của lần chạy.

---

## Bước 2 — Workflow CI

`.github/workflows/ci.yml` chạy trên **mọi Pull Request** vào `develop`/`main` (và chạy tay được). Push thêm commit vào PR → lần chạy cũ bị hủy (`concurrency`).

| Job | Các bước | Đáp ứng yêu cầu |
|---|---|---|
| **`lint`** (~1 phút) | Cài pre-commit (**khóa phiên bản** bằng `lint-constraints.txt`, **chỉ dùng wheel** `--only-binary :all:`) → `black` → `flake8` → `sqlfluff-lint` → các hook còn lại (YAML, file lớn, khóa bí mật, xung đột, xuống dòng) | "Python code linting (flake8, black)", "SQL linting (sqlfluff)" |
| **`dag-tests`** | Chưa có `tests/test_*.py` → **bỏ qua** (thông báo "thêm ở file 05"). Có rồi → chạy trong **image Airflow chính thức `apache/airflow:2.7.1-python3.11`**: cài pytest (chỉ wheel, khóa theo constraints của Airflow) → `airflow db migrate` (SQLite) → `pytest` | Kiểm tra DAG trước khi lên Airflow |
| **`dbt-build`** (~6–8 phút) | Dựng SQL Server (Bước 1) → `dbt debug` → `dbt compile` → `dbt build` → *(từ file 04)* `simulate_new_data` + `dbt source freshness` → `dbt docs generate` → tóm tắt → upload artifact `dbt-ci-artifacts` (tài liệu, manifest, kết quả, log) | "DBT model compilation", "DBT test execution on pull requests", "Automated documentation generation" |

> Vì sao `lint` gọi **pre-commit** thay vì cài black/flake8 riêng? Để CI dùng **đúng phiên bản và cấu hình** như lúc bạn commit ở máy. Local pass thì CI pass.
>
> Vì sao mọi lệnh `pip install` trong CI đều có `--only-binary :all:` và `--constraint`? `--only-binary :all:` chỉ cho cài gói đã đóng gói sẵn (wheel), nên không chạy script cài đặt (`setup.py`) của bất kỳ gói nào; `--constraint` khóa phiên bản mọi gói, kể cả gói phụ thuộc gián tiếp. Hai lớp này chống tấn công chuỗi cung ứng (gói bị chiếm quyền phát hành bản độc hại) và là điều kiện để qua kiểm tra bảo mật của SonarCloud (xem Bước 7.6).
>
> Vì sao `dag-tests` chạy trong image Airflow chính thức thay vì `pip install apache-airflow`? Image có sẵn đúng Airflow 2.7.1, nhanh hơn cài hàng trăm gói; và một số gói Airflow 2.7.1 cần (vd. `pendulum 2.1.2`) **không có wheel** cho Python 3.11, nên không thể cài kèm `--only-binary :all:`.

---

## Bước 3 — Workflow kiểm tra Pull Request

`.github/workflows/pr-validation.yml`, job **`validate-pr`** (không cần database, ~20 giây):

| Kiểm tra | Quy tắc | Vì sao |
|---|---|---|
| 1. Tiêu đề PR | `loại(phạm vi): mô tả`, loại ∈ feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert | Squash merge lấy **tiêu đề PR** làm commit trên `develop` → lịch sử luôn đúng Conventional Commits |
| 2. Tên nhánh | PR vào `develop`: `feature/`, `fix/`, `docs/`, `ci/`, `chore/`... · PR vào `main`: chỉ `develop` hoặc `hotfix/*` | Giữ đúng luồng nhánh |
| 3. File lớn | Không thêm file > 5 MB | Repo gọn, không lỡ đưa dữ liệu/backup lên |
| 4. Xung đột | `git merge-tree` thử merge vào nhánh đích | Phát hiện conflict sớm |

> Tiêu đề lấy qua biến môi trường (`env: PR_TITLE`), không chèn trực tiếp `${{ }}` vào lệnh bash → tránh lỗ hổng *script injection*.

---

## Bước 4 — Macro vận hành (health check, backup, restore)

Các macro này chạy bằng `dbt run-operation <tên>`. Chúng **không liệt kê tên bảng cố định** mà duyệt mọi bảng trong schema của tầng (quyết định D11), nên đổi tên model ở file 04 không làm hỏng deploy.

| Macro | Làm gì | Dùng ở |
|---|---|---|
| `health_check` | Mọi bảng/view trong `<target>_bronze/silver/gold` tồn tại và có ≥ 1 dòng; lỗi → báo đỏ | Bước 6 của mỗi lần deploy |
| `backup_layers` | `prod_gold.X` → `prod_gold__backup.X` (silver + gold) | Trước deploy production |
| `restore_layers` | Chép ngược từ backup; xóa bảng mới do lần deploy lỗi tạo ra | Khi deploy production lỗi |
| `drop_orphan_relations` | Liệt kê (mặc định) hoặc xóa bảng/view không còn model tương ứng | File 04 |

Thử ngay trên máy (chỉ đọc, an toàn):

```bash
docker compose exec dbt dbt run-operation health_check
```

Mong đợi: danh sách các bảng/view trong `dev_bronze`, `dev_silver`, `dev_gold` kèm số dòng, cuối cùng `✅ Health check OK: ...`.

> Thư mục dự án đang có model mới (của file 04) nhưng database dev vẫn là kết quả của model cũ. Health check chỉ đọc database nên vẫn chạy đúng.

---

## Bước 5 — Workflow deploy

### 5.1. `deploy.yml`: khi nào deploy, deploy đi đâu

| Sự kiện | Job | Môi trường (GitHub Environment) | dbt target |
|---|---|---|---|
| Merge vào `develop` | `dev` | `dev` | `dev` |
| Merge vào `main` | `staging` → `production` (chạy sau staging) | `staging`, `production` | `staging`, `prod` |
| Chạy tay (*Run workflow*) | Theo nhánh chọn | | |

`concurrency` đảm bảo 2 lần deploy cùng nhánh không chạy chồng lên nhau. `permissions: contents: write` để gắn tag `prod-*`.

### 5.2. `_deploy.yml`: các bước của một lần deploy

| # | Bước | Ghi chú |
|---|---|---|
| 0 | Dựng SQL Server + dbt (target của môi trường) | Composite action ở Bước 1 |
| 1 | **Pre-deploy validation**: `dbt debug`, `parse`, `compile` | Lỗi ở đây → dừng trước khi đụng tới dữ liệu |
| 2 | *(chỉ prod)* Dựng lại phiên bản production đang chạy | Bỏ qua ở lần deploy production đầu tiên (chưa có tag) → giải thích ở file 07 |
| 3 | *(chỉ prod)* Backup silver + gold | File 07 |
| 4 | `dbt run --full-refresh` | Build lại toàn bộ (database tạm, an toàn khi cấu trúc bảng thay đổi) |
| 5 | `dbt test` | |
| 6 | **Post-deploy health check** | |
| ↩ | *(chỉ prod, khi lỗi)* Rollback tự động | File 07 |
| 7 | *(chỉ prod, khi thành công)* Gắn tag `prod-YYYYMMDD-HHMM` | Lịch sử phiên bản |
| 8 | Tóm tắt dbt + thông báo + upload log `deploy-logs-<env>` | Discord bật ở file 06 |

> Ở bước này, 3 môi trường đã có sẵn trong workflow. File 06 cấu hình thêm **người duyệt** cho production và secret riêng cho từng môi trường; file 07 diễn tập rollback.

---

## Bước 6 — README

`README.md` (thay cho `1. README.md` của giáo viên) gồm: badges trạng thái CI/Deploy/Docs, sơ đồ kiến trúc, bảng đối chiếu yêu cầu → cách đáp ứng, cài đặt nhanh, cách chạy pipeline, CI/CD, giám sát, cấu trúc thư mục, xử lý sự cố, mục lục tài liệu, **khai báo sử dụng AI** (đề bài yêu cầu).

Đủ 4 mục README của MVP: *tổng quan, cài đặt, cách chạy, troubleshooting cơ bản*.

> Một số link trong README (`docs/...`, sơ đồ, trang lineage) sẽ hoạt động sau khi commit các file 04 → 10. Badge Deploy/Docs hiện "no status" cho tới khi workflow tương ứng chạy lần đầu.

---

## Bước 7 — Commit và mở Pull Request

### 7.1. Tạo nhánh

```bash
git switch develop
git pull
git switch -c ci/github-actions
```

### 7.2. Commit theo kế hoạch

```bash
# 0
git add scripts/init_sqlserver.sh
git commit -m "fix(scripts): make SQL Server init script robust for CI"

# 1
git add .github/actions/setup-dbt-stack/action.yml scripts/ci/create_env.sh scripts/ci/dbt.sh scripts/ci/dbt_summary.py
git commit -m "ci: add reusable action to provision SQL Server and dbt"

# 2
git add .github/workflows/ci.yml .github/requirements/lint-constraints.txt
git commit -m "ci: add CI workflow for pull requests"

# 3
git add .github/workflows/pr-validation.yml
git commit -m "ci: add pull request validation workflow"

# 4
git add dbt/macros/ops/_ops_helpers.sql dbt/macros/ops/health_check.sql dbt/macros/ops/backup_layers.sql \
        dbt/macros/ops/restore_layers.sql dbt/macros/ops/drop_orphan_relations.sql
git commit -m "feat(dbt): add operational macros for health check, backup and restore"

# 5
git add .github/workflows/deploy.yml .github/workflows/_deploy.yml scripts/ci/deploy_baseline.sh scripts/ci/notify.py
git commit -m "ci: add deployment workflows for dev, staging and production"

# 6
git add README.md
git commit -m "docs: add project README"

git log --oneline -7        # đủ 7 commit
```

> pre-commit chạy ở mỗi lần commit. Nếu báo `files were modified by this hook`: chạy lại đúng lệnh `git add ...` của commit đó rồi `git commit` lại.

### 7.3. Push và mở Pull Request

```bash
git push -u origin ci/github-actions
gh pr create --base develop \
  --title "ci: add CI/CD pipelines with GitHub Actions" \
  --body "CI (lint, dag-tests, dbt-build), kiểm tra PR, deploy dev/staging/production, macro vận hành, README."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch        # theo dõi tới khi xong (~8–10 phút)
```

Mong đợi:

```
dag-tests     pass   ...
dbt-build     pass   ...
lint          pass   ...
validate-pr   pass   ...
```

### 7.4. Đọc kết quả

1. `gh pr view --web` → tab **Checks** → workflow **CI** → **Summary**: bảng *CI — dbt (target ci)* với `compile`, `build` (với model gốc: `build` ≈ 28 thành công, 0 lỗi).
2. Job `dag-tests`: thông báo *"Chưa có test DAG... bỏ qua"* (đúng, test DAG thêm ở file 05).
3. Cuối trang Summary: artifact **dbt-ci-artifacts** (tải về xem `index.html`, `dbt.log`).

### 7.5. Merge

```bash
gh pr merge --squash --delete-branch
git switch develop
git pull
```

### 7.6. SonarCloud (nếu repo có kết nối)

Nếu tài khoản GitHub của bạn đã cài ứng dụng **SonarCloud**, PR có thêm check **SonarCloud Code Analysis**: SonarCloud tự phân tích code mới của PR và đánh giá theo *Quality Gate* (Sonar way). Check này **không** nằm trong danh sách check bắt buộc (Bước 8), nên đỏ cũng không chặn merge (`gh pr view --json mergeStateStatus` → `UNSTABLE` = vẫn merge được). Nhưng nên giữ nó xanh: đây là bằng chứng tốt cho tiêu chí "code quality checks".

**Xem lý do đỏ:**

```bash
K=farols1505_dbt-airflow-dataops; PR=$(gh pr view --json number --jq .number)
# Điều kiện nào của Quality Gate bị lỗi
curl -s "https://sonarcloud.io/api/qualitygates/project_status?projectKey=$K&pullRequest=$PR" \
  | python3 -c "import sys,json; [print(c['metricKey'], c['status'], c.get('actualValue')) for c in json.load(sys.stdin)['projectStatus']['conditions']]"
# Danh sách vấn đề
curl -s "https://sonarcloud.io/api/issues/search?componentKeys=$K&pullRequest=$PR&resolved=false" \
  | python3 -c "import sys,json; [print(i['type'], i['rule'], i['component'].split(':',1)[1], i.get('line'), '-', i['message']) for i in json.load(sys.stdin)['issues']]"
```

**Lần chạy đầu tiên của PR này** (bản cũ của `ci.yml`), Quality Gate đỏ vì **Security Rating = C**: 3 lỗ hổng ở các lệnh `pip install` trong `ci.yml` (rule `githubactions:S8541`: thiếu `--only-binary :all:`; `githubactions:S8544`: chưa khóa phiên bản), cùng 5 code smell trong script. Đã sửa:

| Vấn đề | Cách sửa |
|---|---|
| `pip install pre-commit` chưa khóa, có thể chạy setup script | `pip install --only-binary :all: --constraint .github/requirements/lint-constraints.txt pre-commit` |
| `pip install apache-airflow ...` có thể chạy setup script | Chạy test trong image `apache/airflow:2.7.1-python3.11`; chỉ cài pytest với `--only-binary :all: --constraint` |
| Shell dùng `[ ]` | Đổi sang `[[ ]]` (`create_env.sh`, `init_sqlserver.sh`) |
| Dùng thẳng tham số `$1` trong hàm | `local query="$1"` (`init_sqlserver.sh`) |
| Biểu thức điều kiện lồng nhau | Tách thành `if / elif` (`dbt_summary.py`) |

**Nếu bạn đã push PR theo bản cũ** (Quality Gate đỏ), thêm 2 commit vào chính nhánh PR rồi push:

```bash
git switch ci/github-actions
git add .github/workflows/ci.yml .github/requirements/lint-constraints.txt
git commit -m "ci: lock dependencies and use binary-only installs in CI"
git add scripts/ci/create_env.sh scripts/ci/dbt_summary.py scripts/init_sqlserver.sh
git commit -m "refactor(scripts): address SonarCloud code smells"
git push
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch        # đủ 5 check xanh, gồm "SonarCloud Code Analysis"
```

> Các PR sau (file 04, 05, 07, 10) có thể bị SonarCloud báo vấn đề mới. Cách xử lý giống hệt: xem bằng 2 lệnh `curl` ở trên → sửa trên nhánh PR → push. Lỗi **bảo mật** (Vulnerability, Security Hotspot) làm Quality Gate đỏ, cần sửa; *code smell* thường chỉ là gợi ý.

---

## Bước 8 — Bật CI bắt buộc

Giờ các check đã chạy ít nhất một lần, bắt buộc chúng phải xanh trước khi merge vào `develop` và `main`:

```bash
for BRANCH in main develop; do
gh api -X PUT "repos/{owner}/{repo}/branches/$BRANCH/protection" --input - <<'EOF'
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["lint", "dag-tests", "dbt-build", "validate-pr"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
done

for b in main develop; do gh api "repos/{owner}/{repo}/branches/$b/protection" --jq '"\(.required_status_checks.contexts)"'; done
# ["dag-tests","dbt-build","lint","validate-pr"] (2 lần)
```

> ⚠️ Tên check phải **trùng đúng** tên job (`lint`, `dag-tests`, `dbt-build`, `validate-pr`). Gõ sai → PR chờ mãi một check không bao giờ chạy. Từ giờ CI đóng vai "người duyệt": PR chỉ merge được khi cả 4 check xanh.

---

## Bước 9 — Kiểm tra deploy dev tự động

Merge ở Bước 7.5 là một lần push vào `develop` → workflow **Deploy** tự chạy job `dev`.

```bash
gh run list --workflow deploy.yml --limit 3
gh run watch            # chọn lần chạy mới nhất
```

Hoặc trên web: **Actions → Deploy → lần chạy mới nhất → job "dev / Deploy → dev"**:
- Các bước 0, 1, 4, 5, 6, 8 xanh; bước 2, 3, 7 *skipped* (chỉ dành cho production).
- **Summary**: thông tin phiên bản, bảng dbt (`run`, `test`), thông báo *"✅ Deploy → dev: thành công"*.
- Artifact **deploy-logs-dev**.

GitHub tự tạo Environment `dev` → xem ở trang repo, cột bên phải, mục **Deployments**.

---

## Bước 10 — Phát hành lần đầu lên main

```bash
gh pr create --base main --head develop \
  --title "chore(release): first release with CI/CD pipelines" \
  --body "Phát hành lần đầu: CI, kiểm tra PR, deploy dev/staging/production, README."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --merge   # MERGE COMMIT, không squash, KHÔNG xóa nhánh develop
```

Merge vào `main` → Deploy chạy `staging` rồi `production`:

```bash
gh run watch
```

- Ở lần đầu, production **chưa cần duyệt** (file 06 sẽ thêm người duyệt).
- Production thành công → tag đầu tiên:

```bash
git fetch --tags
git tag -l 'prod-*'         # vd. prod-20261114-0930
```

✅ **Đạt mốc MVP:** model + test + DAG (bản gốc) chạy được, CI trên Pull Request, deploy tự động khi merge `develop`/`main` với `dbt deps → run → test`, README.

---

## Checklist hoàn thành (mốc MVP)

- [ ] PR #1 đã merge; nhánh yêu cầu 0 người duyệt
- [ ] 7 commit của bước này đã merge vào `develop` qua PR (squash)
- [ ] PR có 4 check xanh: `lint`, `dag-tests`, `dbt-build`, `validate-pr`
- [ ] Bảo vệ nhánh `main`, `develop` bắt buộc 4 check trên
- [ ] Deploy `dev` chạy tự động sau merge, xanh
- [ ] PR phát hành `develop → main` đã merge (merge commit); staging + production xanh
- [ ] Có tag `prod-*` đầu tiên
- [ ] README hiển thị trên trang repo, badge CI xanh

**Đối chiếu MVP (đề bài):**

| Yêu cầu MVP | Trạng thái |
|---|---|
| ≥ 2 bronze, ≥ 1 gold, chạy được | ✅ model gốc (file 04 nâng cấp) |
| `not_null`, `unique` trong `schema.yml` | ✅ test gốc |
| 1 DAG chạy được, có phụ thuộc, lịch chạy | ✅ DAG gốc (file 05 nâng cấp) |
| CI: test tự động trên PR + kiểm tra code | ✅ |
| Deploy: merge `main`/`develop` → `dbt deps/run/test`, xanh/đỏ | ✅ |
| README: tổng quan, cài đặt, cách chạy, troubleshooting | ✅ |

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `gh pr merge 1` báo `At least 1 approving review is required` | Chưa làm Bước 0.1 | Làm Bước 0.1 |
| `git switch develop` báo `Your local changes would be overwritten` | Có file vừa bị sửa ở cả 2 nhánh | `git stash` → switch → `git stash pop` |
| `validate-pr` đỏ ở bước 1 | Tiêu đề PR sai chuẩn | `gh pr edit --title "ci: ..."` (check tự chạy lại) |
| `validate-pr` đỏ ở bước 2 | Tên nhánh sai quy ước | Đổi tên nhánh: `git branch -m ci/...`, push lại, mở PR mới |
| `lint` đỏ ở `black`/`flake8`/`sqlfluff` | Code chưa qua pre-commit (vd. commit bằng `--no-verify`) | `pre-commit run --all-files` ở máy, commit phần sửa |
| `dbt-build` đỏ ở bước *Dựng SQL Server* | Build image hoặc restore lỗi (mạng chậm) | Xem bước *Log container khi lỗi*; *Re-run failed jobs* |
| `dbt-build` đỏ ở `dbt build` | Model/test lỗi | Đọc **Summary** (bảng chi tiết lỗi) hoặc artifact `dbt.log` |
| PR báo `Required status check "lint" is expected` mãi | Tên check ở Bước 8 không khớp tên job | Chạy lại lệnh Bước 8 với tên đúng |
| Check **SonarCloud Code Analysis** đỏ | Quality Gate của SonarCloud không đạt (thường là Security Rating) | Bước 7.6; check này không chặn merge |
| Deploy đỏ ở bước *Build image SQL Server + dbt*: `required variable SA_PASSWORD is missing a value` | (Bản cũ của `_deploy.yml`) secret chưa tạo = chuỗi rỗng, docker compose ưu tiên biến môi trường rỗng hơn `.env` | Đã sửa: workflow truyền secret qua tên `SECRET_SA_PASSWORD` / `SECRET_DBT_PASSWORD`; merge bản sửa rồi deploy lại |
| Deploy production đỏ ở bước 7 (tag) với `Permission denied` | Workflow thiếu quyền ghi | Kiểm tra `permissions: contents: write` trong `deploy.yml`; *Settings → Actions → General → Workflow permissions* |
| `gh pr merge --merge` báo merge commit không được phép | Repo tắt merge commit | `gh repo edit --enable-merge-commit` (file 02, Bước 11.1) |

---

## Tiếp theo

→ **`04_DBT_MODELS_VA_TESTING.md`**: chuẩn hóa model bronze/silver/gold, thêm test đầy đủ và source freshness (Phần 1 + Phần 2, 45 điểm).
