# 02 — GIT, GITHUB VÀ NỀN TẢNG DỰ ÁN (Phần 0)

| | |
|---|---|
| **Ai làm** | **A — Trưởng nhóm**. Riêng [Bước 13](#bước-13--bàn-giao-cho-b-và-c) và [Quy trình làm việc hằng ngày](#quy-trình-làm-việc-hằng-ngày-cho-cả-nhóm) dành cho **cả nhóm** |
| **Khi nào** | Ngày 1–2. **Càng sớm càng tốt**: B và C chỉ push code được sau khi xong file này |
| **Thời gian** | 4–6 giờ |
| **Điều kiện** | Đã xong [`01_CHUAN_BI_MOI_TRUONG.md`](01_CHUAN_BI_MOI_TRUONG.md): 5 container chạy, `dbt run` và `dbt test` pass |
| **Kết quả** | Repo **public** trên GitHub có nhánh `main` + `develop` được bảo vệ; không còn mật khẩu trong code; môi trường dev/staging/prod/ci khai báo sẵn; pre-commit tự kiểm tra code; B và C đã vào repo |

> ⚠️ **Repo public = cả thế giới đọc được.** Trước mỗi lần push, luôn chạy `git status` và chắc chắn **không có file `.env`** trong danh sách.

---

## Mục lục

- [Tổng quan: sẽ thay đổi những gì?](#tổng-quan-sẽ-thay-đổi-những-gì)
- [Bước 1 — Chuẩn bị](#bước-1--chuẩn-bị)
- [Bước 2 — Khởi tạo Git](#bước-2--khởi-tạo-git)
- [Bước 3 — Đưa mật khẩu ra biến môi trường](#bước-3--đưa-mật-khẩu-ra-biến-môi-trường)
- [Bước 4 — Viết lại docker-compose.yml](#bước-4--viết-lại-docker-composeyml)
- [Bước 5 — Script khởi tạo SQL Server](#bước-5--script-khởi-tạo-sql-server)
- [Bước 6 — Thống nhất phiên bản dbt](#bước-6--thống-nhất-phiên-bản-dbt)
- [Bước 7 — Kiểm tra toàn bộ trên máy](#bước-7--kiểm-tra-toàn-bộ-trên-máy)
- [Bước 8 — Công cụ kiểm tra code (pre-commit)](#bước-8--công-cụ-kiểm-tra-code-pre-commit)
- [Bước 9 — Mẫu Pull Request và CODEOWNERS](#bước-9--mẫu-pull-request-và-codeowners)
- [Bước 10 — Tạo repo GitHub và push](#bước-10--tạo-repo-github-và-push)
- [Bước 11 — Cấu hình repo và bảo vệ nhánh](#bước-11--cấu-hình-repo-và-bảo-vệ-nhánh)
- [Bước 12 — Bảng công việc trên GitHub (khuyến nghị)](#bước-12--bảng-công-việc-trên-github-khuyến-nghị)
- [Bước 13 — Bàn giao cho B và C](#bước-13--bàn-giao-cho-b-và-c)
- [Quy trình làm việc hằng ngày (cho cả nhóm)](#quy-trình-làm-việc-hằng-ngày-cho-cả-nhóm)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: sẽ thay đổi những gì?

| File | Hành động | Vì sao |
|---|---|---|
| `.gitignore`, `.gitattributes` | Tạo mới | Không đưa log/bí mật lên Git; chuẩn hóa xuống dòng LF |
| `airflow/plugins/.gitkeep`, `airflow/logs/.gitkeep` | Tạo mới | Git không lưu thư mục rỗng → thiếu thư mục thì build Airflow lỗi |
| `.env.example` / `.env` | Tạo mới | Mẫu biến môi trường (commit) / giá trị thật (**không** commit) |
| `dbt/profiles.yml` | Viết lại | Đọc mật khẩu từ biến môi trường; thêm 4 target `dev`, `staging`, `prod`, `ci` |
| `docker-compose.yml` | Viết lại | Bỏ mật khẩu; cố định tên project; sửa lỗi `docker.sock`; cổng chỉ mở cho localhost; healthcheck |
| `scripts/init_sqlserver.sh` | Tạo mới | Restore DB + tạo login dbt, chạy được nhiều lần; dùng lại trong CI |
| `dbt/requirements.txt`, `dbt/Dockerfile` | Sửa | Một nguồn phiên bản duy nhất: dbt-core 1.8.7 + dbt-sqlserver 1.8.7 |
| `dbt/macros/generate_schema_name.sql` | Tạo mới | Sửa cách đặt tên schema của adapter → mỗi môi trường có schema riêng (`dev_bronze`, `prod_gold`...) |
| `.pre-commit-config.yaml`, `.sqlfluff`, `.sqlfluffignore`, `.flake8`, `pyproject.toml` | Tạo mới | Tự động kiểm tra code Python/SQL/YAML và commit message |
| `.github/pull_request_template.md`, `.github/CODEOWNERS` | Tạo mới | Mẫu PR; tự động gán người review theo thư mục |

**Kế hoạch commit** (đúng chuẩn Conventional Commits, để giáo viên thấy lịch sử rõ ràng):

| # | Commit message | Bước |
|---|---|---|
| 1 | `chore: import course template` | 2 |
| 2 | `refactor: read credentials from environment variables` | 3 |
| 3 | `fix(docker): pin project name, fix docker socket access, bind ports to localhost` | 4 |
| 4 | `feat(scripts): add idempotent SQL Server init script` | 5 |
| 5 | `build(dbt): pin dbt-core and dbt-sqlserver to 1.8.7` | 6 |
| 6 | `fix(dbt): prefix layer schemas with target schema` | 7.5 |
| 7 | `ci: add pre-commit hooks for black, flake8 and sqlfluff` | 8 |
| 8 | `style: apply automatic formatting` | 8 |
| 9 | `chore(github): add pull request template and CODEOWNERS` | 9 |

> 📝 **Ngoại lệ duy nhất:** 9 commit này đi **thẳng vào `main`** vì repo chưa có ai khác. Từ Bước 11 trở đi, **mọi** thay đổi (kể cả của trưởng nhóm) phải qua Pull Request.

---

## Bước 1 — Chuẩn bị

### 1.1. Kiểm tra công cụ

```bash
cd ~/HCMUS/Advanced_DevOps/DataOps/dbt_airflow_project   # thư mục dự án của bạn
docker compose ps              # 5 container đang Up
gh auth status                 # đã đăng nhập GitHub
pre-commit --version           # đã cài ở file 01, Bước 1.5
python3 --version              # >= 3.9
```

### 1.2. Lấy username GitHub của B và C

Bạn cần cho [Bước 9](#bước-9--mẫu-pull-request-và-codeowners) và [Bước 11](#bước-11--cấu-hình-repo-và-bảo-vệ-nhánh). Ghi lại:

```
A (bạn): ______________     B: ______________     C: ______________
```

### 1.3. Dọn file thừa

```bash
rm -f sqlserver/Dockerfile.bak     # bản cũ của sqlserver/Dockerfile, không dùng tới
rm -f mdpdf.log                    # log của công cụ xuất PDF, không liên quan dự án
rm -rf airflow/dags/__pycache__
```

> Nếu bạn đã tạo `docker-compose.override.yml` ở file 01 (sửa tạm lỗi docker.sock), **giữ nguyên** lúc này. Ta sẽ xóa nó ở Bước 7.

---

## Bước 2 — Khởi tạo Git

### 2.1. Tạo `.gitignore`

Tạo file `.gitignore` ở thư mục gốc:

```gitignore
# ===== Bí mật — KHÔNG BAO GIỜ commit =====
.env
docker-compose.override.yml

# ===== Python =====
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/

# ===== dbt =====
dbt/target/
dbt/dbt_packages/
dbt/logs/
dbt/.user.yml

# ===== Airflow =====
airflow/logs/*
!airflow/logs/.gitkeep

# ===== Khác =====
*.log
*.bak
.DS_Store
Thumbs.db
.idea/
.vscode/
```

### 2.2. Tạo `.gitattributes`

Phần lớn file trong dự án gốc đang dùng **xuống dòng kiểu Windows (CRLF)**. File này bắt Git lưu mọi file văn bản theo kiểu **LF**:

```gitattributes
# Chuẩn hóa xuống dòng kiểu LF (Linux) cho mọi file văn bản.
# Tránh lỗi "/bin/bash^M: bad interpreter" khi có thành viên dùng Windows.
* text=auto eol=lf
*.sh text eol=lf

# File nhị phân — không đụng tới
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.pdf binary
*.bak binary
```

### 2.3. Giữ các thư mục rỗng

```bash
mkdir -p airflow/plugins airflow/logs
touch airflow/plugins/.gitkeep airflow/logs/.gitkeep
```

### 2.4. Commit đầu tiên

```bash
git init -b main
git add -A
git status                      # đọc kỹ danh sách!
```

**Kiểm tra trước khi commit:** danh sách **không** được có `airflow/logs/...` (trừ `.gitkeep`), `dbt/target/`, `dbt/dbt_packages/`, `dbt/logs/`, `*.log`. (Lúc này chưa có `.env`.)

```bash
git commit -m "chore: import course template"
```

### 2.5. Chuẩn hóa xuống dòng trong thư mục làm việc

Commit ở 2.4 đã lưu file dạng LF **trong Git**, nhưng file trên ổ đĩa vẫn là CRLF. Lấy lại bản LF từ Git:

```bash
git rm -rq --cached .
git reset -q --hard
```

> Hai lệnh này **an toàn** ở thời điểm này: chỉ ghi đè các file đã commit bằng chính nội dung vừa commit (đã đổi sang LF). File bị `.gitignore` (log, `target/`...) không bị đụng tới.

Kiểm tra:

```bash
git status                                               # phải "nothing to commit, working tree clean"
git ls-files | xargs grep -lI $'\r' | wc -l              # phải in ra 0
```

> 💡 **Mật khẩu cũ trong lịch sử Git:** commit 1 chứa các mật khẩu mẫu của giáo viên (vốn đã công khai trong tài liệu môn học). Ở các bước sau ta **đổi** mật khẩu dbt, Postgres và khóa Fernet, và chỉ mở cổng cho `localhost`. Vì vậy lịch sử chứa mật khẩu cũ không gây hại, không cần viết lại lịch sử.

---

## Bước 3 — Đưa mật khẩu ra biến môi trường

### 3.1. Tạo `.env.example` (file mẫu, **có** commit)

```bash
# =============================================================================
# MẪU BIẾN MÔI TRƯỜNG — copy thành file .env rồi điền giá trị:
#     cp .env.example .env
# File .env chứa bí mật → ĐÃ nằm trong .gitignore, TUYỆT ĐỐI không commit.
# Quy tắc: không dấu cách, không dấu nháy, không ký tự $ trong giá trị.
# =============================================================================

# ----- SQL Server -----
# Mật khẩu tài khoản sa. Nếu database đã được tạo trước đó (đã làm file 01),
# PHẢI giữ đúng mật khẩu cũ: YourStrong@Passw0rd
SA_PASSWORD=YourStrong@Passw0rd

# ----- dbt -----
# Tài khoản SQL riêng cho dbt (script scripts/init_sqlserver.sh sẽ tạo).
# Mật khẩu: >= 8 ký tự, có chữ HOA + chữ thường + số, CHỈ dùng chữ và số
# (vì mật khẩu này còn được ghép vào URL kết nối của Airflow).
DBT_USER=dbt_user
DBT_ENV_SECRET_PASSWORD=DoiMatKhauNay2026
DBT_DATABASE=AdventureWorks2014
# Môi trường mặc định khi chạy local: dev | staging | prod
DBT_TARGET=dev

# ----- Airflow -----
POSTGRES_PASSWORD=DoiMatKhauNay2026
# Tạo khóa mới bằng lệnh:
#   python3 -c "import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
AIRFLOW_FERNET_KEY=
# Mật khẩu đăng nhập Airflow UI (user: admin)
AIRFLOW_ADMIN_PASSWORD=admin

# ----- Docker -----
# Linux: chạy  stat -c '%g' /var/run/docker.sock  rồi điền số in ra
# Windows (WSL) / macOS (Docker Desktop): để 0
DOCKER_GID=0

# ----- Thông báo -----
# URL webhook Discord/Slack (C sẽ gửi riêng). Để trống = không gửi thông báo.
NOTIFY_WEBHOOK_URL=
```

> **Vì sao biến mật khẩu tên là `DBT_ENV_SECRET_PASSWORD` (dài vậy)?** dbt có quy ước: biến nào bắt đầu bằng `DBT_ENV_SECRET_` sẽ được **tự động che** (`*****`) trong mọi log. Log dbt sẽ được upload lên GitHub Actions (repo public), nên đây là lớp bảo vệ thêm.

### 3.2. Tạo `.env` (giá trị thật, **không** commit)

```bash
cp .env.example .env

# Sinh khóa Fernet mới và ghi vào .env
sed -i "s|^AIRFLOW_FERNET_KEY=.*|AIRFLOW_FERNET_KEY=$(python3 -c 'import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())')|" .env

# Lấy GID của docker socket (Linux) và ghi vào .env
sed -i "s|^DOCKER_GID=.*|DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)|" .env
```

Mở `.env` bằng VS Code và sửa:
- `DBT_ENV_SECRET_PASSWORD`: mật khẩu mới **chỉ gồm chữ và số**, có chữ hoa, chữ thường, số, ≥ 8 ký tự (vd. `Dbt2026Local`).
- `POSTGRES_PASSWORD`: mật khẩu khác bất kỳ (chữ và số).
- `SA_PASSWORD`: **giữ nguyên** `YourStrong@Passw0rd`. Database của bạn đã được tạo với mật khẩu này; đổi ở đây sẽ không kết nối được.

Kiểm tra `.env` đã bị Git bỏ qua:

```bash
git check-ignore -v .env        # phải in ra: .gitignore:2:.env   .env
```

> 💡 Mỗi thành viên có `.env` **riêng** trên máy mình, giá trị có thể khác nhau (vì mỗi máy có SQL Server riêng). **Không cần** gửi file `.env` cho nhau.

### 3.3. Viết lại `dbt/profiles.yml`

Thay **toàn bộ** nội dung `dbt/profiles.yml` bằng:

```yaml
# Cấu hình kết nối dbt. KHÔNG ghi mật khẩu ở đây — mọi giá trị nhạy cảm lấy từ biến môi trường.
dbt_airflow_project:
  # Target mặc định = dev. Đổi bằng biến DBT_TARGET hoặc tham số --target.
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev: &sqlserver_defaults
      type: sqlserver
      driver: "ODBC Driver 17 for SQL Server"
      server: "{{ env_var('DBT_SERVER', 'sqlserver') }}"
      port: "{{ env_var('DBT_PORT', '1433') | as_number }}"
      database: "{{ env_var('DBT_DATABASE', 'AdventureWorks2014') }}"
      schema: dev
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_ENV_SECRET_PASSWORD') }}"
      encrypt: false
      trust_cert: true
      threads: 4
      retries: 3

    staging:
      <<: *sqlserver_defaults
      schema: staging

    prod:
      <<: *sqlserver_defaults
      schema: prod

    ci:
      <<: *sqlserver_defaults
      schema: ci
```

**Giải thích:**
- `&sqlserver_defaults` / `<<: *sqlserver_defaults`: cú pháp YAML "copy cấu hình". 3 target sau giống `dev`, **chỉ khác `schema`**.
- dbt ghép `schema` của target với tên tầng trong `dbt_project.yml` (`+schema: bronze`...) → bảng nằm ở `dev_bronze`, `dev_silver`, `dev_gold`; `prod_bronze`... Đây chính là cách tách môi trường (quyết định **D3** trong file 00).
- Thiếu biến `DBT_USER` → dbt báo lỗi rõ ràng: `Env var required but not provided: 'DBT_USER'`.

### 3.4. Commit

Chưa chạy thử được (container dbt chưa có biến môi trường, phải sửa `docker-compose.yml` trước). Commit luôn:

```bash
git add .env.example dbt/profiles.yml
git status                       # KHÔNG được thấy .env
git commit -m "refactor: read credentials from environment variables"
```

---

## Bước 4 — Viết lại `docker-compose.yml`

### 4.1. Những gì thay đổi so với bản gốc

| Thay đổi | Lý do |
|---|---|
| `name: dbt_airflow_project` | Tên container luôn là `dbt_airflow_project-dbt-1` dù thư mục tên gì → DAG không bị lỗi *No such container* |
| Mọi mật khẩu/khóa → `${BIEN}` đọc từ `.env` | Không còn bí mật trong repo public. Thiếu biến bắt buộc → báo lỗi tiếng Việt ngay khi chạy |
| `group_add: ["${DOCKER_GID}"]` cho Airflow | **Sửa lỗi `permission denied ... docker.sock`** (lỗi làm DAG của bạn thất bại ngày 31/10) |
| Cổng `127.0.0.1:1433`, `127.0.0.1:8080` | Chỉ máy bạn truy cập được. Bản gốc mở cho cả mạng LAN với mật khẩu `sa` công khai |
| `healthcheck` cho `sqlserver` và `airflow-webserver` | Biết chính xác khi nào dịch vụ sẵn sàng; CI dùng `--wait` |
| Scheduler chờ webserver **healthy** | Tránh scheduler chạy khi database Airflow chưa khởi tạo xong |
| `restart: unless-stopped` | Container tự bật lại khi lỗi/khởi động lại máy |
| Biến cho dbt (`DBT_*`) và Airflow (`AIRFLOW_VAR_DBT_TARGET`, `AIRFLOW_CONN_MSSQL_DEFAULT`, `NOTIFY_WEBHOOK_URL`) | Chuẩn bị sẵn cho C (DAG, thông báo) và B (target) → **chỉ sửa file này một lần** (quyết định **D10**) |
| Dùng `x-airflow-common` | 2 service Airflow dùng chung cấu hình, không lặp code |

### 4.2. Nội dung mới

Thay **toàn bộ** `docker-compose.yml` bằng:

```yaml
# =============================================================================
# Hạ tầng local của dự án DataOps (dbt + Airflow + SQL Server)
# - Mọi mật khẩu/khóa lấy từ file .env (KHÔNG commit .env). Mẫu: .env.example
# - Các cổng chỉ mở cho máy local (127.0.0.1), không lộ ra mạng LAN.
# =============================================================================

# Cố định tên project → tên container luôn là dbt_airflow_project-<service>-1,
# dù thư mục dự án tên gì (DAG Airflow gọi container dbt theo tên này).
name: dbt_airflow_project

# Biến môi trường dùng chung cho 2 container Airflow
x-airflow-env: &airflow-env
  AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:${POSTGRES_PASSWORD:?Thiếu POSTGRES_PASSWORD trong .env}@postgres/airflow
  AIRFLOW__CORE__EXECUTOR: LocalExecutor
  AIRFLOW__CORE__LOAD_EXAMPLES: "False"
  AIRFLOW__CORE__FERNET_KEY: ${AIRFLOW_FERNET_KEY:?Thiếu AIRFLOW_FERNET_KEY trong .env}
  # Airflow Variable "dbt_target" (DAG đọc để chọn môi trường dev/staging/prod)
  AIRFLOW_VAR_DBT_TARGET: ${DBT_TARGET:-dev}
  # Airflow Connection "mssql_default" (dùng cho các task kiểm tra dữ liệu bằng SQL)
  AIRFLOW_CONN_MSSQL_DEFAULT: mssql://${DBT_USER}:${DBT_ENV_SECRET_PASSWORD}@sqlserver:1433/${DBT_DATABASE:-AdventureWorks2014}
  # Webhook Discord/Slack để gửi thông báo (để trống = không gửi)
  NOTIFY_WEBHOOK_URL: ${NOTIFY_WEBHOOK_URL:-}

# Cấu hình dùng chung cho 2 container Airflow
x-airflow-common: &airflow-common
  build:
    context: ./airflow
    dockerfile: Dockerfile
  environment: *airflow-env
  # Cho user "airflow" trong container quyền dùng Docker socket của máy host
  # (DAG chạy "docker exec" vào container dbt). Linux: GID nhóm docker; Win/Mac: 0
  group_add:
    - "${DOCKER_GID:-0}"
  volumes:
    - ./airflow/dags:/opt/airflow/dags
    - ./airflow/logs:/opt/airflow/logs
    - ./airflow/plugins:/opt/airflow/plugins
    - ./dbt:/opt/airflow/dbt
    - /var/run/docker.sock:/var/run/docker.sock
  restart: unless-stopped
  networks:
    - dbt_airflow_network

services:
  sqlserver:
    build:
      context: ./sqlserver
      dockerfile: Dockerfile
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: ${SA_PASSWORD:?Thiếu SA_PASSWORD trong .env}
      MSSQL_PID: Express
    ports:
      - "127.0.0.1:1433:1433"
    volumes:
      - sqlserver_data:/var/opt/mssql
    healthcheck:
      # $$ = để biến được đọc bên trong container, không phải lúc docker compose đọc file
      test: ["CMD-SHELL", "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P \"$$MSSQL_SA_PASSWORD\" -Q 'SELECT 1' -b -o /dev/null"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s
    restart: unless-stopped
    networks:
      - dbt_airflow_network

  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Thiếu POSTGRES_PASSWORD trong .env}
      POSTGRES_DB: airflow
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - dbt_airflow_network

  airflow-webserver:
    <<: *airflow-common
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "127.0.0.1:8080:8080"
    command: >
      bash -c "airflow db init &&
      airflow users create --username admin --firstname Admin --lastname User
      --role Admin --email admin@example.com --password ${AIRFLOW_ADMIN_PASSWORD:-admin} &&
      airflow webserver"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 90s

  airflow-scheduler:
    <<: *airflow-common
    depends_on:
      # Chờ webserver khởi tạo xong database Airflow rồi mới chạy scheduler
      airflow-webserver:
        condition: service_healthy
    command: airflow scheduler

  dbt:
    build:
      context: ./dbt
      dockerfile: Dockerfile
    depends_on:
      - sqlserver
    environment:
      DBT_TARGET: ${DBT_TARGET:-dev}
      DBT_SERVER: sqlserver
      DBT_PORT: "1433"
      DBT_DATABASE: ${DBT_DATABASE:-AdventureWorks2014}
      DBT_USER: ${DBT_USER:?Thiếu DBT_USER trong .env}
      DBT_ENV_SECRET_PASSWORD: ${DBT_ENV_SECRET_PASSWORD:?Thiếu DBT_ENV_SECRET_PASSWORD trong .env}
    volumes:
      - ./dbt:/usr/app/dbt
    command: tail -f /dev/null  # Giữ container chạy để Airflow "docker exec" vào
    restart: unless-stopped
    networks:
      - dbt_airflow_network

volumes:
  sqlserver_data:
  postgres_data:

networks:
  dbt_airflow_network:
    driver: bridge
```

### 4.3. Kiểm tra cú pháp

```bash
docker compose config --quiet && echo "✅ docker-compose.yml hợp lệ"
```

Kiểm tra biến đã được điền đúng (không in mật khẩu ra màn hình):

```bash
docker compose config | grep -E "group_add|- \"?[0-9]+\"?$|127.0.0.1|name: dbt_airflow_project"
```

Phải thấy `name: dbt_airflow_project`, số GID của bạn dưới `group_add`, và `host_ip: 127.0.0.1`.

### 4.4. Commit

```bash
git add docker-compose.yml
git commit -m "fix(docker): pin project name, fix docker socket access, bind ports to localhost"
```

---

## Bước 5 — Script khởi tạo SQL Server

Thay cho 2 lệnh thủ công ở file 01 (Bước 5 và 6). Script này:
- **chờ** SQL Server sẵn sàng (thay vì `sleep 20` cố định);
- chỉ **restore** khi chưa có database;
- **tạo** login dbt nếu chưa có, hoặc **cập nhật mật khẩu** cho khớp `.env` nếu đã có;
- chạy bao nhiêu lần cũng được → dùng lại nguyên vẹn trong GitHub Actions (file 06).

### 5.1. Tạo `scripts/init_sqlserver.sh`

```bash
mkdir -p scripts
```

Nội dung file `scripts/init_sqlserver.sh`:

```bash
#!/usr/bin/env bash
# =============================================================================
# Khởi tạo SQL Server cho dự án:
#   1. Chờ SQL Server sẵn sàng
#   2. Restore database AdventureWorks2014 (nếu chưa có)
#   3. Tạo / cập nhật tài khoản SQL cho dbt (lấy từ .env)
#
# Chạy bao nhiêu lần cũng được (idempotent). Dùng cho máy local VÀ GitHub Actions.
# Cách chạy (tại thư mục gốc dự án):   ./scripts/init_sqlserver.sh
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

# Đọc biến từ .env (nếu có). Trên GitHub Actions biến có thể đến từ Secrets.
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

: "${DBT_USER:?Thiếu DBT_USER (xem .env.example)}"
: "${DBT_ENV_SECRET_PASSWORD:?Thiếu DBT_ENV_SECRET_PASSWORD (xem .env.example)}"
DB_NAME="AdventureWorks2014"
MAX_TRIES=30   # 30 lần x 5 giây = tối đa 150 giây

# Chạy một câu SQL bằng tài khoản sa, bên trong container sqlserver.
# Mật khẩu sa đọc từ biến MSSQL_SA_PASSWORD của chính container.
run_sql() {
  docker compose exec -T sqlserver bash -c \
    '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -h -1 -W -Q "$1"' \
    _ "$1"
}

echo "⏳ [1/3] Chờ SQL Server sẵn sàng..."
for i in $(seq 1 "$MAX_TRIES"); do
  if run_sql "SELECT 1" > /dev/null 2>&1; then
    echo "   ✅ SQL Server đã sẵn sàng"
    break
  fi
  if [ "$i" -eq "$MAX_TRIES" ]; then
    echo "   ❌ SQL Server không phản hồi. Xem log: docker compose logs sqlserver"
    exit 1
  fi
  sleep 5
done

echo "⏳ [2/3] Kiểm tra database $DB_NAME..."
db_count=$(run_sql "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '$DB_NAME'" | tr -d '[:space:]')
if [ "$db_count" = "0" ]; then
  echo "   Chưa có → đang restore từ /tmp/AdventureWorks2014.bak (khoảng 30 giây)..."
  run_sql "RESTORE DATABASE [$DB_NAME] FROM DISK = '/tmp/AdventureWorks2014.bak'
           WITH MOVE 'AdventureWorks2014_Data' TO '/var/opt/mssql/data/AdventureWorks2014.mdf',
                MOVE 'AdventureWorks2014_Log' TO '/var/opt/mssql/data/AdventureWorks2014_log.ldf'"
  echo "   ✅ Đã restore $DB_NAME"
else
  echo "   ✅ Đã có sẵn, bỏ qua restore"
fi

echo "⏳ [3/3] Tạo/cập nhật tài khoản dbt: $DBT_USER..."
run_sql "SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$DBT_USER')
    CREATE LOGIN [$DBT_USER] WITH PASSWORD = N'$DBT_ENV_SECRET_PASSWORD';
ELSE
    ALTER LOGIN [$DBT_USER] WITH PASSWORD = N'$DBT_ENV_SECRET_PASSWORD';
USE [$DB_NAME];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$DBT_USER')
    CREATE USER [$DBT_USER] FOR LOGIN [$DBT_USER];
ALTER ROLE db_owner ADD MEMBER [$DBT_USER];"
echo "   ✅ Tài khoản $DBT_USER sẵn sàng (quyền db_owner trên $DB_NAME)"

echo "🎉 Khởi tạo SQL Server hoàn tất."
```

```bash
chmod +x scripts/init_sqlserver.sh
bash -n scripts/init_sqlserver.sh && echo "✅ cú pháp OK"
```

> Script sẽ được **chạy thật** ở Bước 7 (sau khi container được tạo lại với cấu hình mới).

### 5.2. Commit

```bash
git add scripts/init_sqlserver.sh
git commit -m "feat(scripts): add idempotent SQL Server init script"
```

> `git add` trên Linux lưu luôn quyền thực thi (`chmod +x`), nên B và C clone về là chạy được ngay.

---

## Bước 6 — Thống nhất phiên bản dbt

Hiện tại `dbt/requirements.txt` ghi `dbt-core==1.7.3`, còn `dbt/Dockerfile` lại cài `1.8.7`. Ta biến `requirements.txt` thành **nguồn phiên bản duy nhất**.

### 6.1. Thay toàn bộ `dbt/requirements.txt`

```text
# Phiên bản dbt dùng cho TOÀN dự án (Docker local + GitHub Actions).
# Đổi phiên bản = chỉ sửa ở đây, rồi: docker compose build dbt
dbt-core==1.8.7
dbt-sqlserver==1.8.7
```

(Bỏ `pyodbc`, `python-dotenv`, `dbt-utils`: `pyodbc` được `dbt-sqlserver` tự cài; `dbt_utils` là **package dbt** khai báo trong `packages.yml`, không phải thư viện pip.)

### 6.2. Sửa `dbt/Dockerfile`

Tìm đoạn:

```dockerfile
# Install specific version of dbt-core and related packages
RUN pip install --no-cache-dir \
    dbt-core==1.8.7 \
    dbt-sqlserver==1.8.7
```

Thay bằng:

```dockerfile
# Cài dbt theo đúng phiên bản trong requirements.txt (nguồn phiên bản duy nhất)
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
```

### 6.3. Commit

```bash
git add dbt/requirements.txt dbt/Dockerfile
git commit -m "build(dbt): pin dbt-core and dbt-sqlserver to 1.8.7"
```

---

## Bước 7 — Kiểm tra toàn bộ trên máy

Giờ áp dụng cấu hình mới vào hệ thống đang chạy.

### 7.1. Xóa file sửa tạm (nếu có)

```bash
rm -f docker-compose.override.yml     # đã thay bằng group_add trong docker-compose.yml
```

### 7.2. Làm mới database của Airflow

Ta đã đổi khóa Fernet và mật khẩu Postgres, nên database metadata cũ của Airflow (chỉ chứa lịch sử chạy DAG, không có gì quan trọng) không dùng được nữa. Xóa nó đi; Airflow sẽ tự tạo lại khi khởi động.

```bash
docker compose down                                   # dừng và xóa container (KHÔNG có -v)
docker volume rm dbt_airflow_project_postgres_data    # chỉ xóa volume của Postgres/Airflow
docker volume ls | grep dbt_airflow_project           # phải CÒN dbt_airflow_project_sqlserver_data
```

> 🛑 **Không** xóa `dbt_airflow_project_sqlserver_data`. Đó là database AdventureWorks.

### 7.3. Build lại dbt và khởi động

```bash
docker compose build dbt          # Dockerfile của dbt vừa đổi
docker compose up -d
```

Đợi 2–3 phút, rồi:

```bash
docker compose ps
```

Mong đợi: `sqlserver` và `airflow-webserver` hiện **`(healthy)`**, `postgres` `(healthy)`, `dbt` và `airflow-scheduler` `Up`.

### 7.4. Chạy script khởi tạo

```bash
./scripts/init_sqlserver.sh
```

Mong đợi:

```
⏳ [1/3] Chờ SQL Server sẵn sàng...
   ✅ SQL Server đã sẵn sàng
⏳ [2/3] Kiểm tra database AdventureWorks2014...
   ✅ Đã có sẵn, bỏ qua restore
⏳ [3/3] Tạo/cập nhật tài khoản dbt: dbt_user...
   ✅ Tài khoản dbt_user sẵn sàng (quyền db_owner trên AdventureWorks2014)
🎉 Khởi tạo SQL Server hoàn tất.
```

Chạy lại lần 2 → kết quả y hệt, không lỗi (chứng minh script idempotent).

### 7.5. Kiểm tra dbt với cấu hình mới

```bash
docker compose exec dbt dbt debug
```

Trong phần `Connection:` của output phải có `schema: dev`, `UID: dbt_user` (adapter SQL Server gọi tên đăng nhập là **UID**), dòng `Connection test: [OK connection ok]` và cuối cùng `All checks passed!`.

```bash
docker compose exec dbt dbt deps
```

> `dbt deps` có thể in `Updated version available: 1.4.1` cho `dbt_utils`. Đó **không phải lỗi**, chỉ là thông báo có bản mới. Ta cố ý giữ bản `1.1.1` ghi trong `packages.yml` để mọi người dùng cùng phiên bản.

#### Sửa cách đặt tên schema (bắt buộc)

Adapter `dbt-sqlserver` 1.8 (kế thừa `dbt-fabric`) **ghi đè** cách đặt tên schema chuẩn của dbt: nó chỉ dùng tên tầng (`bronze`, `silver`, `gold`) và **bỏ qua** schema của target. Hậu quả: `dev`, `staging`, `prod` sẽ ghi **chung** vào một schema `bronze`. Như vậy không có môi trường riêng, và quyết định D3 cùng Bonus 4 hỏng.

Sửa bằng một macro của dự án (macro trong dự án được ưu tiên hơn macro của adapter). Tạo file `dbt/macros/generate_schema_name.sql`:

```sql
{#
    Đặt tên schema = <schema của target>_<tên tầng>, ví dụ: dev_bronze, prod_gold.

    Vì sao cần file này? Adapter dbt-sqlserver 1.8 (kế thừa dbt-fabric) ghi đè cách
    đặt tên mặc định của dbt và chỉ dùng tên tầng (bronze/silver/gold), bỏ qua target.
    Khi đó dev, staging và prod sẽ ghi CHUNG vào một schema → không tách được môi trường.
    Macro này khôi phục hành vi chuẩn của dbt.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

Commit:

```bash
git add dbt/macros/generate_schema_name.sql
git commit -m "fix(dbt): prefix layer schemas with target schema"
```

#### Chạy toàn bộ model và test

```bash
docker compose exec dbt dbt build        # = dbt run + dbt test, chạy theo thứ tự phụ thuộc
```

Mong đợi ở cuối output:

```
Done. PASS=28 WARN=0 ERROR=0 SKIP=0 TOTAL=28
```

(28 = 10 model + 18 test.)

Kiểm tra các schema theo môi trường đã được tạo:

```bash
docker compose exec -T sqlserver bash -c '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d AdventureWorks2014 -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.schemas WHERE name LIKE '\''dev[_]%'\'' ORDER BY name"'
```

Mong đợi: `dev_bronze`, `dev_silver`, `dev_gold`.

> Thử nhanh target khác (không bắt buộc): `docker compose exec dbt dbt run --target staging --select path:models/bronze` → tạo schema `staging_bronze`.
>
> Các schema cũ `bronze`, `silver`, `gold` (tạo ra trước khi có macro, từ file 01) vẫn còn và không ảnh hưởng gì. Có thể bỏ qua.

### 7.6. Kiểm tra Airflow

1. Mở http://localhost:8080, đăng nhập `admin` / mật khẩu `AIRFLOW_ADMIN_PASSWORD` trong `.env`.
2. DAG `dbt_transform` đang **tắt (paused)** vì Airflow vừa khởi tạo lại. DAG đang tắt thì bấm Trigger cũng **không chạy** (lần chạy chỉ đứng ở trạng thái *queued*). Vì vậy: **gạt công tắc bên trái tên DAG sang bật**, rồi bấm ▶ **Trigger DAG**.
3. Đợi 1–2 phút: `dbt_run` và `dbt_test` phải **🟩 xanh**. Lỗi `docker.sock` đã được sửa.
4. **Gạt công tắc tắt DAG lại** (DAG này chạy mỗi 5 phút). C sẽ thay bằng DAG mới.

✅ Nếu tất cả xanh: nền tảng hạ tầng đã xong.

---

## Bước 8 — Công cụ kiểm tra code (pre-commit)

**pre-commit** chạy các công cụ kiểm tra **mỗi lần `git commit`**: tự format Python (black), báo lỗi Python (flake8), tự sửa và kiểm tra SQL (sqlfluff), chặn commit message sai chuẩn. CI ở file 06 sẽ chạy **đúng các công cụ và cấu hình này**, nên lỗi được bắt ngay trên máy, không đợi CI báo đỏ.

### 8.1. Tạo các file cấu hình

**`.pre-commit-config.yaml`**

```yaml
# =============================================================================
# Kiểm tra code tự động mỗi lần "git commit".
# Cài một lần sau khi clone:   pre-commit install
# Chạy thủ công cho mọi file:  pre-commit run --all-files
# =============================================================================
default_install_hook_types: [pre-commit, commit-msg]
exclude: ^(airflow/logs/|dbt/target/|dbt/dbt_packages/|dbt/logs/)

repos:
  # Kiểm tra chung
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: mixed-line-ending
        args: [--fix=lf]
      - id: check-yaml
      - id: check-added-large-files
        args: [--maxkb=5120]
      - id: check-merge-conflict
      - id: detect-private-key

  # Python: tự format bằng black, kiểm tra lỗi bằng flake8
  - repo: https://github.com/psf/black-pre-commit-mirror
    rev: 26.10.1
    hooks:
      - id: black
  - repo: https://github.com/pycqa/flake8
    rev: 7.4.1
    hooks:
      - id: flake8

  # SQL (dbt models): tự sửa rồi kiểm tra bằng sqlfluff
  - repo: https://github.com/sqlfluff/sqlfluff
    rev: 4.4.0
    hooks:
      - id: sqlfluff-fix
        files: ^dbt/models/
      - id: sqlfluff-lint
        files: ^dbt/models/

  # Commit message phải theo Conventional Commits (feat:, fix:, docs:, ...)
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v4.4.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
```

**`.sqlfluff`**

```ini
# Cấu hình sqlfluff cho dbt models (SQL Server = dialect tsql)
[sqlfluff]
dialect = tsql
templater = jinja
max_line_length = 120
# Tắt một số rule không phù hợp với dbt / dữ liệu AdventureWorks:
#   AM04: cho phép "select *" (mẫu CTE chuẩn của dbt)
#   AL09: cho phép đổi tên chỉ khác chữ hoa/thường (vd. Status as status)
#   CP02: tên cột nguồn kiểu PascalCase (CustomerID) lẫn snake_case
#   RF04: tên cột trùng từ khóa (Name, Status, Size...)
#   ST06: không bắt buộc thứ tự cột trong select
exclude_rules = AM04, AL09, CP02, RF04, ST06

[sqlfluff:indentation]
tab_space_size = 4

[sqlfluff:templater:jinja]
# Hiểu các hàm của dbt: ref(), source(), config(), var(), env_var()...
apply_dbt_builtins = True

[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.functions]
extended_capitalisation_policy = lower

[sqlfluff:rules:capitalisation.literals]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.types]
extended_capitalisation_policy = lower
```

**`.sqlfluffignore`**

```text
dbt/target/
dbt/dbt_packages/
dbt/logs/
```

**`.flake8`**

```ini
[flake8]
# Đồng bộ với black (line-length = 100 trong pyproject.toml)
max-line-length = 100
extend-ignore = E203, W503
exclude = .git, __pycache__, .venv, venv, airflow/logs, dbt/target, dbt/dbt_packages
```

**`pyproject.toml`**

```toml
[tool.black]
line-length = 100
target-version = ["py39"]   # Airflow 2.7.1 chạy Python 3.9
```

> 💡 **Vì sao sqlfluff chỉ kiểm tra `dbt/models/`?** Thư mục `dbt/tests/generic/` (B làm ở file 04) chứa khối `{% test %}` đặc thù của dbt mà templater `jinja` không hiểu. Test vẫn được dbt kiểm tra khi chạy.

### 8.2. Commit cấu hình

```bash
git add .pre-commit-config.yaml .sqlfluff .sqlfluffignore .flake8 pyproject.toml
git commit -m "ci: add pre-commit hooks for black, flake8 and sqlfluff"
```

### 8.3. Cài hook và chạy lần đầu cho toàn bộ code

```bash
pre-commit install                    # cài hook pre-commit + commit-msg vào .git/hooks
pre-commit run --all-files            # lần đầu: tải công cụ (2–5 phút), rồi tự sửa file
```

Lần chạy đầu **sẽ báo `Failed`** ở một số hook kèm dòng `files were modified by this hook`. Đó là **bình thường**: hook đã **tự sửa** file:
- `trailing-whitespace`, `end-of-file-fixer`: xóa khoảng trắng thừa, thêm dòng trống cuối file;
- `black`: format lại `airflow/dags/dbt_dag.py`;
- `sqlfluff-fix`: thêm `as` cho alias bảng (`from source c` → `from source as c`), chuẩn hóa thụt lề.

Chạy lại lần 2:

```bash
git add -u                 # chỉ các file ĐÃ được Git theo dõi (không kéo theo file mới như .github/)
pre-commit run --all-files
```

Lần này **mọi hook phải `Passed`**:

```
trim trailing whitespace.................................................Passed
fix end of files.........................................................Passed
mixed line ending........................................................Passed
check yaml...............................................................Passed
check for added large files..............................................Passed
check for merge conflicts................................................Passed
detect private key.......................................................Passed
black....................................................................Passed
flake8...................................................................Passed
sqlfluff-fix.............................................................Passed
sqlfluff-lint............................................................Passed
```

### 8.4. Kiểm tra dbt vẫn chạy đúng sau khi format SQL

sqlfluff chỉ đổi cách viết, không đổi logic. Chạy lại cho chắc:

```bash
docker compose exec dbt dbt build        # vẫn phải PASS=28
```

### 8.5. Commit phần format

```bash
git status                               # KHÔNG được thấy .env
git commit -m "style: apply automatic formatting"
```

Lúc commit, pre-commit chạy và kiểm tra luôn commit message (`Conventional Commit....Passed`).

**Thử cơ chế chặn commit message sai** (không bắt buộc):

```bash
git commit --allow-empty -m "update stuff"     # bị CHẶN: "Bad commit message"
git commit --allow-empty -m "chore: test hook" # được chấp nhận
git reset --soft HEAD~1                        # xóa commit thử vừa tạo
```

---

## Bước 9 — Mẫu Pull Request và CODEOWNERS

### 9.1. `.github/pull_request_template.md`

GitHub tự điền nội dung này mỗi khi ai đó mở PR:

```bash
mkdir -p .github
```

```markdown
## Mô tả
<!-- PR này làm gì? Vì sao cần? -->

## Issue liên quan
Closes #

## Loại thay đổi
- [ ] `feat` — tính năng mới
- [ ] `fix` — sửa lỗi
- [ ] `test` — thêm/sửa test
- [ ] `docs` — tài liệu
- [ ] `ci` / `build` — CI/CD, Docker, phiên bản
- [ ] `refactor` / `style` / `chore` — khác

## Đã kiểm tra
- [ ] `pre-commit run --all-files` pass
- [ ] Sửa dbt → `docker compose exec dbt dbt build` pass trên máy
- [ ] Sửa DAG → DAG hiện trong Airflow UI, không có "Broken DAG"
- [ ] Không commit mật khẩu, `.env`, URL webhook
- [ ] Đã cập nhật tài liệu liên quan (nếu cần)

## Ảnh chụp / log (nếu có)
```

### 9.2. `.github/CODEOWNERS`

File này **tự động yêu cầu review** từ người phụ trách thư mục khi PR chạm vào thư mục đó (theo bảng sở hữu file ở mục 9.4 của file 00). Thay `ten-github-A/B/C` bằng username thật (giữ dấu `@`):

```text
# Ai phụ trách phần nào → tự động được yêu cầu review khi PR chạm vào.
# Quy tắc ở DƯỚI được ưu tiên hơn quy tắc ở TRÊN.

# Mặc định: trưởng nhóm
*                               @ten-github-A

# B — dbt models, tests
/dbt/                           @ten-github-B
/scripts/simulate_new_data.sql  @ten-github-B

# C — Airflow, monitoring, tài liệu
/airflow/                       @ten-github-C
/tests/                         @ten-github-C
/monitoring/                    @ten-github-C
/docs/                          @ten-github-C
/README.md                      @ten-github-C

# A — hạ tầng, CI/CD (đặt cuối để ưu tiên)
/.github/                       @ten-github-A
/dbt/profiles.yml               @ten-github-A
/dbt/macros/generate_schema_name.sql  @ten-github-A
/dbt/Dockerfile                 @ten-github-A
/dbt/requirements.txt           @ten-github-A
/docker-compose*.yml            @ten-github-A
/scripts/init_sqlserver.sh      @ten-github-A
```

> Ta **không** bật tùy chọn "bắt buộc code owner duyệt". Nếu bật, PR của B sửa `dbt/` sẽ cần chính B duyệt, mà GitHub không cho tự duyệt PR của mình. CODEOWNERS ở đây chỉ để **tự gán người review**.

### 9.3. Commit

```bash
git add .github/
git commit -m "chore(github): add pull request template and CODEOWNERS"
git log --oneline                 # phải thấy đủ 9 commit
```

---

## Bước 10 — Tạo repo GitHub và push

### 10.1. Tạo repo public

```bash
gh repo create dbt-airflow-dataops --public --source=. --remote=origin \
  --description "DataOps pipeline: dbt + Apache Airflow + SQL Server + GitHub Actions"
```

(Đổi `dbt-airflow-dataops` thành tên bạn muốn.)

### 10.2. Kiểm tra lần cuối trước khi đưa lên public

```bash
git ls-files | grep -E '(^|/)\.env$' && echo "🛑 DỪNG LẠI: .env đang bị theo dõi!" || echo "✅ .env không có trong repo"
git grep -nE 'Dbt2026|DoiMatKhau' -- ':!.env.example' || echo "✅ không thấy mật khẩu thật"
```

(Thay `Dbt2026` bằng một đoạn trong mật khẩu thật của bạn.)

### 10.3. Push `main` và tạo `develop`

```bash
git push -u origin main
git switch -c develop
git push -u origin develop
```

Mở repo trên trình duyệt: `gh repo view --web`.

---

## Bước 11 — Cấu hình repo và bảo vệ nhánh

### 11.1. Cài đặt chung

```bash
gh repo edit \
  --default-branch develop \
  --enable-merge-commit \
  --enable-squash-merge \
  --enable-rebase-merge=false \
  --delete-branch-on-merge \
  --enable-issues \
  --enable-projects
```

| Cài đặt | Ý nghĩa |
|---|---|
| Nhánh mặc định = `develop` | Clone về ở `develop`; PR mới tự nhắm vào `develop` |
| Cho phép **Squash merge** | Dùng cho PR `feature/* → develop`: gộp thành 1 commit, message = **tiêu đề PR** (đã đúng Conventional Commits) |
| Cho phép **Merge commit** | Dùng cho PR `develop → main` (phát hành): giữ nguyên lịch sử, `main` và `develop` không bị lệch nhau |
| Tắt Rebase merge | Bớt một lựa chọn gây nhầm lẫn |
| Tự xóa nhánh sau khi merge | Repo gọn gàng |

### 11.2. Mời B và C

```bash
gh api -X PUT "repos/{owner}/{repo}/collaborators/ten-github-B" -f permission=push
gh api -X PUT "repos/{owner}/{repo}/collaborators/ten-github-C" -f permission=push
```

(`{owner}/{repo}` để nguyên, `gh` tự điền theo repo hiện tại.) B và C sẽ nhận email mời → phải bấm **Accept**.

### 11.3. Bảo vệ nhánh `main` và `develop`

```bash
for BRANCH in main develop; do
gh api -X PUT "repos/{owner}/{repo}/branches/$BRANCH/protection" --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
done
```

| Quy tắc | Ý nghĩa |
|---|---|
| `required_approving_review_count: 1` | Mọi PR cần **1 người khác** duyệt |
| `dismiss_stale_reviews` | Push thêm code sau khi được duyệt → phải duyệt lại |
| `enforce_admins: true` | Áp dụng **cả cho trưởng nhóm**: không ai push thẳng được |
| `required_conversation_resolution` | Mọi bình luận review phải được giải quyết |
| Cấm force-push, cấm xóa nhánh | Bảo vệ lịch sử |
| `required_status_checks: null` | **Tạm thời** chưa bắt buộc CI (chưa có CI). **File 06** sẽ bật lại, bắt buộc CI xanh |

Kiểm tra trên web: *Settings → Branches* → thấy 2 rule cho `main` và `develop`.

Kiểm tra bằng thực tế:

```bash
git switch develop
git commit --allow-empty -m "chore: test branch protection"
git push                          # phải bị TỪ CHỐI: "protected branch"
git reset --hard origin/develop   # xóa commit thử
```

---

## Bước 12 — Bảng công việc trên GitHub (khuyến nghị)

Issues + Project board giúp cả nhóm biết ai đang làm gì. Đây cũng là **bằng chứng đóng góp** khi giáo viên đánh giá chéo.

### 12.1. Tạo milestone theo tuần

```bash
gh api "repos/{owner}/{repo}/milestones" -f title="Tuần 1 - MVP"
gh api "repos/{owner}/{repo}/milestones" -f title="Tuần 2 - Đủ 100 điểm"
gh api "repos/{owner}/{repo}/milestones" -f title="Tuần 3 - Bonus và tài liệu"
```

### 12.2. Tạo issue cho mọi đầu việc

Chạy **sau khi B và C đã Accept lời mời** (nếu không, gán người sẽ lỗi). Sửa 3 dòng đầu rồi dán cả khối vào terminal:

```bash
A=ten-github-A; B=ten-github-B; C=ten-github-C
W1="Tuần 1 - MVP"; W2="Tuần 2 - Đủ 100 điểm"; W3="Tuần 3 - Bonus và tài liệu"

while IFS='|' read -r WHO MS TITLE GUIDE; do
  gh issue create --assignee "$WHO" --milestone "$MS" --title "$TITLE" \
    --body "Hướng dẫn: \`project/$GUIDE\`" > /dev/null && echo "✅ $TITLE"
done <<EOF
$A|$W1|chore: nền tảng Git, .env, pre-commit (Phần 0)|02_GIT_GITHUB_VA_NEN_TANG.md
$A|$W1|ci: CI workflow cho Pull Request|06_CI_PIPELINE.md
$A|$W1|ci: kiểm tra PR (tiêu đề, kích thước file, conflict)|06_CI_PIPELINE.md
$A|$W1|ci: deploy đơn giản khi merge develop/main|07_CD_VA_MULTI_ENV.md
$A|$W2|ci: môi trường dev/staging/prod + duyệt production|07_CD_VA_MULTI_ENV.md
$A|$W2|ci: pre-deploy validation + post-deploy health check|07_CD_VA_MULTI_ENV.md
$A|$W2|ci: thông báo deploy + gắn tag prod-*|07_CD_VA_MULTI_ENV.md
$A|$W2|ci: backup + rollback tự động khi test lỗi|08_ROLLBACK_VA_GIAM_SAT_DEPLOY.md
$A|$W2|chore: ghép nối end-to-end cả nhóm|00_TONG_QUAN_DU_AN.md
$A|$W3|ci: workflow rollback thủ công|08_ROLLBACK_VA_GIAM_SAT_DEPLOY.md
$A|$W3|ci: báo cáo tỉ lệ deploy thành công|08_ROLLBACK_VA_GIAM_SAT_DEPLOY.md
$A|$W3|docs: DEPLOYMENT_RUNBOOK + ROLLBACK + badges|08_ROLLBACK_VA_GIAM_SAT_DEPLOY.md
$B|$W1|refactor: tách bronze 1-1 với bảng nguồn, gộp sources|03_DBT_MODELS.md
$B|$W1|feat: source freshness + simulate_new_data.sql|04_DBT_TESTING.md
$B|$W1|feat: silver models|03_DBT_MODELS.md
$B|$W2|fix: sửa logic gold + thêm model gold mới|03_DBT_MODELS.md
$B|$W2|perf: incremental/index + đo hiệu năng|03_DBT_MODELS.md
$B|$W2|test: relationships + accepted_values|04_DBT_TESTING.md
$B|$W2|test: custom generic tests + singular tests|04_DBT_TESTING.md
$B|$W2|docs: mô tả mọi model và cột|03_DBT_MODELS.md
$B|$W3|feat: exposures + lineage lên GitHub Pages|10_LINEAGE_GITHUB_PAGES.md
$B|$W3|docs: TESTING.md + PERFORMANCE.md|04_DBT_TESTING.md
$C|$W1|feat: DAG dbt_pipeline theo tầng + retry|05_AIRFLOW_DAG.md
$C|$W1|feat: thông báo lỗi qua Discord|05_AIRFLOW_DAG.md
$C|$W1|test: DAG integrity test|05_AIRFLOW_DAG.md
$C|$W2|feat: kiểm tra chất lượng dữ liệu bằng SQL trong DAG|05_AIRFLOW_DAG.md
$C|$W2|feat: Grafana + dashboard|09_GRAFANA_MONITORING.md
$C|$W2|docs: ARCHITECTURE + sơ đồ kiến trúc|11_TAI_LIEU_VA_DEMO.md
$C|$W3|docs: README + SETUP_GUIDE + TROUBLESHOOTING|11_TAI_LIEU_VA_DEMO.md
$C|$W3|docs: kịch bản demo (DEMO_SCRIPT)|11_TAI_LIEU_VA_DEMO.md
EOF
```

Đóng luôn issue Phần 0 sau khi xong file này:

```bash
gh issue list --search "nền tảng Git" --json number --jq '.[0].number' | xargs -I{} gh issue close {} --comment "Hoàn thành theo project/02_GIT_GITHUB_VA_NEN_TANG.md"
```

### 12.3. Tạo Project board (trên web)

1. Trang repo → tab **Projects** → **Link a project** → **New project** → chọn mẫu **Board** → đặt tên `DataOps Board`.
2. Trong board: **+ Add item** → gõ `#` → chọn lần lượt các issue (hoặc *Workflows* → bật **Auto-add to project** cho repo này).
3. Cột: `Todo` → `In Progress` → `Done`. Mỗi người tự kéo thẻ của mình.

---

## Bước 13 — Bàn giao cho B và C

### 13.1. Tin nhắn gửi nhóm (copy và sửa)

```text
Repo đã sẵn sàng: https://github.com/<ten-github-A>/dbt-airflow-dataops
1. Accept lời mời trong email GitHub.
2. Làm theo project/02_GIT_GITHUB_VA_NEN_TANG.md → Bước 13.2 (khoảng 30 phút).
3. Xong thì gửi ảnh chụp: dbt build PASS=28 + Airflow DAG xanh.
Từ giờ KHÔNG push thẳng develop/main, mọi thứ đi qua Pull Request.
Mỗi người tự tạo .env trên máy mình theo .env.example, KHÔNG gửi .env cho nhau.
```

### 13.2. Việc B và C cần làm (≈ 30 phút)

> Phần này dành cho **B và C**. Chạy trong terminal (Windows: terminal WSL).

**1. Dừng hệ thống cũ** (dùng thư mục dự án cũ từ file 01):

```bash
cd ~/dbt_airflow_project          # thư mục cũ của bạn
docker compose down               # KHÔNG dùng -v (giữ database AdventureWorks)
cd ~
mv dbt_airflow_project dbt_airflow_project_old   # giữ lại phòng khi cần, xóa sau
```

**2. Clone repo** (nhánh mặc định là `develop`):

```bash
git clone git@github.com:<ten-github-A>/dbt-airflow-dataops.git dbt_airflow_project
cd dbt_airflow_project
git branch --show-current         # develop
```

**3. Tạo `.env`:**

```bash
cp .env.example .env
sed -i "s|^AIRFLOW_FERNET_KEY=.*|AIRFLOW_FERNET_KEY=$(python3 -c 'import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())')|" .env
```

Mở `.env` sửa `DBT_ENV_SECRET_PASSWORD`, `POSTGRES_PASSWORD` (chữ + số, có hoa/thường/số). Giữ `SA_PASSWORD=YourStrong@Passw0rd`. Riêng **Linux**: điền `DOCKER_GID` bằng kết quả của `stat -c '%g' /var/run/docker.sock`. Windows/macOS: để `0`.

**4. Làm mới Airflow, build và khởi động:**

```bash
chmod -R 777 airflow/logs                             # Linux / WSL
docker volume rm dbt_airflow_project_postgres_data    # xóa metadata Airflow cũ (không phải database dữ liệu)
docker compose build
docker compose up -d
```

Đợi 2–3 phút, `docker compose ps` thấy `sqlserver` và `airflow-webserver` `(healthy)`.

**5. Khởi tạo SQL Server và kiểm tra dbt:**

```bash
./scripts/init_sqlserver.sh
docker compose exec dbt dbt deps
docker compose exec dbt dbt build                     # PASS=28
```

**6. Kiểm tra Airflow:** http://localhost:8080 → đăng nhập `admin` / `AIRFLOW_ADMIN_PASSWORD` → **bật** DAG `dbt_transform` (gạt công tắc) → Trigger → 2 task 🟩 → **tắt** DAG lại.

**7. Cài pre-commit:**

```bash
pre-commit install
pre-commit run --all-files        # lần đầu tải công cụ; mọi hook phải Passed
```

**8.** Nếu mọi thứ OK: `rm -rf ~/dbt_airflow_project_old`. Gửi ảnh chụp cho trưởng nhóm.

---

## Quy trình làm việc hằng ngày (cho cả nhóm)

```
develop ──┬──────────────────────────────────────┬──► (A phát hành) ──► main
          │                                      ▲
          └─► feature/ten-viec ──► Pull Request ─┘ (1 người duyệt → Squash and merge)
```

### Bắt đầu một việc mới

```bash
git switch develop
git pull                                    # luôn lấy code mới nhất trước
git switch -c feature/bronze-refactor       # tên nhánh: feature/..., fix/..., docs/..., ci/...
```

### Trong lúc làm

```bash
git add -A
git commit -m "refactor: split bronze models by source table"
```

- pre-commit chạy tự động. Nếu báo `files were modified by this hook` → **chạy lại** `git add -A` rồi `git commit` lần nữa (hook đã tự sửa file giúp bạn).
- Nếu báo `Bad commit message` → viết lại theo mẫu `loại: mô tả ngắn` (tiếng Anh, chữ thường, không dấu chấm cuối).

| Loại | Dùng khi |
|---|---|
| `feat` | Thêm tính năng (model mới, task DAG mới, workflow mới) |
| `fix` | Sửa lỗi |
| `test` | Thêm/sửa test |
| `docs` | Tài liệu |
| `refactor` | Sửa cấu trúc, không đổi kết quả |
| `perf` | Tối ưu hiệu năng |
| `style` | Format code |
| `ci` / `build` | CI/CD / Docker, phiên bản |
| `chore` | Việc lặt vặt khác |

### Đưa lên GitHub và mở Pull Request

```bash
git push -u origin feature/bronze-refactor
gh pr create --base develop --fill          # hoặc tạo trên web
```

- **Tiêu đề PR** cũng theo Conventional Commits (vd. `refactor: split bronze models by source table`), vì khi *Squash and merge*, tiêu đề PR thành commit trên `develop`.
- Điền mẫu PR (tự hiện), ghi `Closes #<số issue>` để issue tự đóng khi merge.
- Người review được CODEOWNERS tự gán. Nhắn họ trong nhóm chat.

### Review và merge

- **Người review:** đọc thay đổi (tab *Files changed*), chạy thử nếu cần (`gh pr checkout <số PR>`), rồi **Approve** hoặc **Request changes**.
- **Tác giả:** sau khi được duyệt → **Squash and merge** → nhánh tự xóa.
- Sau khi merge:
  ```bash
  git switch develop && git pull
  ```

### Phát hành `develop → main` (chỉ A)

```bash
gh pr create --base main --head develop --title "chore(release): <mô tả đợt phát hành>"
```

→ B hoặc C duyệt → A merge bằng **Create a merge commit** (không squash).

---

## Checklist hoàn thành

**Trên máy A**
- [ ] 9 commit đúng Conventional Commits (`git log --oneline`)
- [ ] Có macro `dbt/macros/generate_schema_name.sql`
- [ ] Không còn file CRLF (`git ls-files | xargs grep -lI $'\r' | wc -l` = 0)
- [ ] `.env` tồn tại, bị Git bỏ qua, không có trong repo
- [ ] `docker compose ps`: `sqlserver`, `airflow-webserver`, `postgres` `(healthy)`
- [ ] `./scripts/init_sqlserver.sh` chạy 2 lần đều thành công
- [ ] `dbt debug` hiện `schema: dev`, `UID: dbt_user`, `All checks passed!`
- [ ] `dbt build` → `PASS=28`; có schema `dev_bronze`, `dev_silver`, `dev_gold`
- [ ] DAG `dbt_transform` chạy 🟩 (lỗi docker.sock đã hết)
- [ ] `pre-commit run --all-files`: mọi hook `Passed`

**Trên GitHub**
- [ ] Repo **public**, có `main` và `develop`, nhánh mặc định là `develop`
- [ ] Squash + Merge commit bật, Rebase tắt, tự xóa nhánh sau merge
- [ ] Bảo vệ `main` và `develop` (push thẳng bị từ chối)
- [ ] B và C đã Accept lời mời
- [ ] CODEOWNERS có username thật
- [ ] *(Khuyến nghị)* Milestone + issue + Project board

**Bàn giao**
- [ ] B và C đã làm xong Bước 13.2 và gửi ảnh chụp

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `required variable SA_PASSWORD is missing a value: Thiếu SA_PASSWORD trong .env` | Chưa có `.env` hoặc thiếu biến | `cp .env.example .env` và điền đủ |
| Script dừng ở bước 1, báo SQL Server không phản hồi; log `sqlserver` có `Login failed for user 'sa'` | `SA_PASSWORD` trong `.env` khác mật khẩu lúc database được tạo | Đặt lại `SA_PASSWORD=YourStrong@Passw0rd`, `docker compose up -d sqlserver`, chạy lại script |
| `Password validation failed` khi tạo login | Mật khẩu dbt quá yếu | ≥ 8 ký tự, có chữ hoa, chữ thường, số |
| `dbt debug`: `Env var required but not provided: 'DBT_USER'` | Container dbt được tạo trước khi có `.env` | `docker compose up -d --force-recreate dbt` |
| `dbt debug`: `Login failed for user 'dbt_user'` | Chưa chạy script, hoặc vừa đổi mật khẩu trong `.env` | `./scripts/init_sqlserver.sh` (script cập nhật mật khẩu) rồi `docker compose up -d --force-recreate dbt` |
| `airflow-webserver` không `healthy`, log có `InvalidToken` / `Fernet` | Database Airflow cũ được mã hóa bằng khóa Fernet cũ | Làm lại Bước 7.2 (xóa volume postgres) |
| Log webserver: `password authentication failed for user "airflow"` | Volume Postgres cũ dùng mật khẩu `airflow` | Làm lại Bước 7.2 |
| Task Airflow vẫn lỗi `permission denied ... docker.sock` | `DOCKER_GID` sai | `stat -c '%g' /var/run/docker.sock`, sửa `.env`, `docker compose up -d` |
| `./scripts/init_sqlserver.sh: Permission denied` | File mất quyền thực thi | `chmod +x scripts/init_sqlserver.sh` (hoặc chạy `bash scripts/init_sqlserver.sh`) |
| pre-commit: `files were modified by this hook` | Hook đã tự sửa file | `git add -A` rồi commit lại |
| pre-commit: `Bad commit message` | Message sai chuẩn | Viết lại dạng `feat: ...`, `fix: ...` |
| sqlfluff báo lỗi không tự sửa được | Lỗi cần sửa tay (vd. dòng quá 120 ký tự) | Đọc mã lỗi (vd. `LT05`), sửa theo gợi ý; tra cứu: `sqlfluff rules <mã>` |
| `git push` bị từ chối: `protected branch` | Đúng như thiết kế | Tạo nhánh `feature/...` và mở PR |
| `gh api ... collaborators` báo `404` | Sai username, hoặc chưa ở trong thư mục repo | Kiểm tra username; chạy lệnh trong thư mục dự án |
| `gh issue create` báo lỗi assignee | B/C chưa Accept lời mời | Đợi Accept rồi chạy lại Bước 12.2 |

---

## Tiếp theo

| Ai | Làm gì |
|---|---|
| **A** | → `06_CI_PIPELINE.md`: dựng SQL Server trong GitHub Actions, `ci.yml`, `pr-validation.yml`, bật bắt buộc CI trong bảo vệ nhánh |
| **B** | → `03_DBT_MODELS.md` (sau khi xong Bước 13.2) |
| **C** | → `05_AIRFLOW_DAG.md` (sau khi xong Bước 13.2) |
