# Xử lý sự cố

Ghi lại các lỗi đã gặp trong quá trình làm dự án: **hiện tượng → nguyên nhân → cách sửa**.

## 1. Docker và cài đặt

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `required variable SA_PASSWORD is missing a value` | Chưa có `.env` | `cp .env.example .env` và điền giá trị |
| `Bind for 127.0.0.1:1433 failed: port is already allocated` | Cổng bị chiếm (SQL Server cài sẵn, container cũ) | Tắt chương trình đó; `docker ps` → `docker stop ...` |
| `sqlserver` thoát `Exited (137)` | Thiếu RAM | Tăng RAM cho Docker (≥ 6 GB) |
| `sqlserver` không healthy, log `Login failed for user 'sa'` | `SA_PASSWORD` khác mật khẩu lúc volume được tạo | Đặt lại mật khẩu cũ trong `.env`, `docker compose up -d` |
| `/bin/bash^M: bad interpreter` | File `.sh` bị chuyển sang CRLF (Windows) | `git config --global core.autocrlf input`, clone lại |
| Build Airflow lỗi `failed to compute cache key ... /plugins` | Thiếu thư mục `airflow/plugins` | `mkdir -p airflow/plugins` (repo đã có `.gitkeep`) |
| Mac chip Apple: `exec format error` / lỗi `msodbcsql17` | Image build dạng ARM | `export DOCKER_DEFAULT_PLATFORM=linux/amd64`, build lại `--no-cache` |
| `./scripts/init_sqlserver.sh: Permission denied` | Mất quyền thực thi | `bash scripts/init_sqlserver.sh` |
| `docker compose exec ...` thoát mã 1 mà **không in gì** khi chuyển output vào file (`> log.txt`) | Docker cài bằng **snap** không được ghi thẳng vào file | Dùng pipe: `... \| tee log.txt`. Các script của dự án đã tự cho output đi qua pipe |
| Sửa biến trong `.env` (vd. `DBT_TARGET`) nhưng container vẫn dùng giá trị cũ | Biến môi trường của terminal **được ưu tiên hơn** `.env` (VS Code có thể tự nạp `.env` vào terminal) | `env \| grep DBT_` để kiểm tra; `unset DBT_TARGET` hoặc mở terminal mới, rồi `docker compose up -d` |

## 2. dbt

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `Env var required but not provided: 'DBT_USER'` | Container dbt tạo trước khi có `.env` | `docker compose up -d --force-recreate dbt` |
| `Login failed for user 'dbt_user'` | Chưa tạo login / vừa đổi mật khẩu | `./scripts/init_sqlserver.sh` → `docker compose up -d --force-recreate dbt` |
| Bảng nằm ở schema `bronze` thay vì `dev_bronze` | Thiếu macro `generate_schema_name` | Khôi phục `dbt/macros/generate_schema_name.sql` |
| `slvr_sales_orders` lỗi `Invalid column name 'modified_at'` | Bảng cũ (trước khi chuyển sang incremental) còn trong database | `dbt build --full-refresh --select slvr_sales_orders+` |
| Còn view/bảng cũ (vd. `dev_bronze.brnz_customers`) sau khi đổi tên model | dbt không tự xóa object không còn model | `dbt run-operation drop_orphan_relations --args '{dry_run: false}'` |
| `dbt source freshness` báo `ERROR STALE` | Dữ liệu AdventureWorks cũ (2014) | `dbt run-operation simulate_new_data` rồi chạy lại |
| `Updated version available` khi `dbt deps` | Chỉ là thông báo | Bỏ qua (phiên bản được ghim trong `packages.yml`) |
| `dbt debug` không có dòng `user:` | Adapter SQL Server hiển thị là `UID:` | Bình thường |
| Test `dbt_utils.expression_is_true` lỗi `Create View or Function failed because no column name was specified for column 1 (4511)` | dbt-sqlserver bọc SQL của test trong `CREATE VIEW`; bản gốc của dbt_utils sinh `select 1` (cột không tên) | Macro `dbt/macros/compat/sqlserver__test_expression_is_true.sql` + cấu hình `dispatch` trong `dbt_project.yml` (đã có) |
| `dbt ls ... \| wc -l` ra số lớn hơn 3 | `dbt ls` in thêm 3 dòng log | Dùng `dbt -q ls ...` |
| `dbt show --inline "... order by ..."` lỗi `Incorrect syntax near the keyword 'order'` | `dbt show` bọc câu truy vấn trong subquery, SQL Server không cho `ORDER BY` ở đó | Bỏ `ORDER BY`, dùng `--limit` |

## 3. Airflow

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| Task lỗi `permission denied ... docker.sock` | `DOCKER_GID` sai | `stat -c '%g' /var/run/docker.sock` → sửa `.env` → `docker compose up -d` |
| Task lỗi `No such container: dbt_airflow_project-dbt-1` | Container dbt không chạy | `docker compose up -d dbt` |
| Trigger DAG nhưng đứng ở *queued* | DAG đang tắt (paused) | Gạt công tắc bật DAG |
| Webserver không healthy, log `InvalidToken`/`Fernet` hoặc `password authentication failed for user "airflow"` | Volume Postgres cũ tạo bằng khóa/mật khẩu khác | `docker compose down` → `docker volume rm dbt_airflow_project_postgres_data` → `docker compose up -d` |
| `silver.dbt_test` lỗi `Invalid object name '<target>_gold....'` khi chạy target mới lần đầu | `dbt test --select path:models/silver` mặc định (`eager`) kéo cả test gold↔silver vào, lúc gold chưa build | Thêm `--indirect-selection buildable` (DAG hiện tại đã có) |
| *Broken DAG* trên giao diện | Lỗi import trong file DAG | Bấm thông báo đỏ xem chi tiết; chạy `pytest` (xem `tests/`) |
| `check_sqlserver` lỗi đăng nhập | Connection `mssql_default` dùng mật khẩu dbt cũ | Sửa `.env` → `docker compose up -d` (tạo lại container Airflow) |
| Không nhận thông báo Discord | `NOTIFY_WEBHOOK_URL` trống/sai, chưa tạo lại container | Điền URL → `docker compose up -d`; xem log task tìm dòng "Discord" |
| Airflow log `Permission denied: '/opt/airflow/logs/...'` | Container không ghi được log | `chmod -R 777 airflow/logs` |

## 4. Git, pre-commit, GitHub Actions

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| pre-commit `files were modified by this hook` | Hook đã tự sửa file | `git add` lại các file đó rồi commit lại |
| pre-commit `Bad commit message` | Sai Conventional Commits | Viết lại dạng `feat: ...`, `fix: ...` |
| `git push` bị từ chối `protected branch` | Đúng thiết kế | Tạo nhánh `feature/...`, mở PR |
| PR không merge được: `Required status check ... is expected` | CI chưa chạy xong hoặc đỏ | `gh pr checks --watch`; sửa lỗi rồi push lại |
| `gh pr checks --watch` báo `no checks reported on the '...' branch` rồi thoát | Chạy ngay sau `gh pr create`/`git push`, GitHub chưa kịp tạo check (cần ~5 giây) | Đợi vài giây rồi chạy lại; khối lệnh trong hướng dẫn đã có `sleep 20` |
| File vừa commit "biến mất" sau `git switch develop` | `gh pr merge` thất bại (check chưa xong) nên PR **chưa merge**; file chỉ nằm trên nhánh tính năng | Không mất gì: `gh pr checks <số PR> --watch && gh pr merge <số PR> --squash --delete-branch`, rồi `git pull` |
| Sau khi phát hành, GitHub hiện banner *"main had recent pushes — Compare & pull request"*; bấm vào thì PR `main → develop` bị `validate-pr` đỏ | PR ngược chiều, không cần thiết: chỉ chứa merge commit của lần phát hành, **0 file** thay đổi | Bỏ qua banner; nếu đã lỡ mở: `gh pr close <số PR>` |
| Job `validate-pr` đỏ ở bước tiêu đề | Tiêu đề PR sai chuẩn | `gh pr edit --title "feat: ..."` |
| Check **SonarCloud Code Analysis** đỏ (Security Rating C) | `pip install` không khóa phiên bản / có thể chạy setup script (rule S8541, S8544) | Mọi `pip install` trong workflow dùng `--only-binary :all:` + `--constraint`; xem `project/03_...` Bước 7.6 |
| Job `dbt-build` đỏ ở bước dựng SQL Server | Build image/restore lỗi | Xem bước "Log container khi lỗi" |
| Deploy đỏ ở bước *Build image SQL Server + dbt*: `required variable SA_PASSWORD is missing a value` | (Bản cũ của `_deploy.yml`) secret chưa tạo = chuỗi rỗng, docker compose ưu tiên biến môi trường rỗng hơn `.env` | Đã sửa: workflow truyền secret qua tên `SECRET_SA_PASSWORD` / `SECRET_DBT_PASSWORD`; merge bản sửa rồi deploy lại |
| Job production đứng ở *Waiting* | Chờ duyệt | Actions → *Review deployments* → Approve |
| Deploy production đỏ nhưng có "Đã rollback" | Lỗi đã được rollback tự động | Xem `docs/ROLLBACK.md` |
| Workflow Pages lỗi `Branch "main" is not allowed to deploy to github-pages` | Luật của environment `github-pages` chỉ cho nhánh mặc định | Thêm nhánh `main` vào deployment branch policy (xem `project/10_...`) |
