# 01 — CHUẨN BỊ MÔI TRƯỜNG

| | |
|---|---|
| **Trạng thái** | ✅ **Đã xong trên máy chính.** Dùng lại file này khi cần cài trên **máy khác** (vd. máy dùng để demo) hoặc làm lại từ đầu |
| **Thời gian** | 1–2 giờ (phần lớn là chờ tải và build image) |
| **Kết quả** | Máy chạy được toàn bộ hệ thống từ repo: SQL Server có dữ liệu, `dbt build` thành công, Airflow UI mở được, pre-commit hoạt động |
| **Tài liệu trước** | [`00_TONG_QUAN_DU_AN.md`](00_TONG_QUAN_DU_AN.md) |

> 💡 File này cài hệ thống **từ repo GitHub** (đã có `.env.example`, `scripts/init_sqlserver.sh`... từ file `02`). File `02` là việc **làm một lần** cho repo, máy mới **không cần** làm lại `02`.

---

## Mục lục

- [Bước 0 — Kiểm tra máy](#bước-0--kiểm-tra-máy)
- [Bước 1 — Cài công cụ](#bước-1--cài-công-cụ)
- [Bước 2 — Lấy mã nguồn](#bước-2--lấy-mã-nguồn)
- [Bước 3 — Tạo file .env](#bước-3--tạo-file-env)
- [Bước 4 — Chuẩn bị riêng theo hệ điều hành](#bước-4--chuẩn-bị-riêng-theo-hệ-điều-hành)
- [Bước 5 — Build và khởi động các container](#bước-5--build-và-khởi-động-các-container)
- [Bước 6 — Khởi tạo SQL Server](#bước-6--khởi-tạo-sql-server)
- [Bước 7 — Kiểm tra dbt](#bước-7--kiểm-tra-dbt)
- [Bước 8 — Kiểm tra Airflow](#bước-8--kiểm-tra-airflow)
- [Bước 9 — Xem dữ liệu bằng VS Code](#bước-9--xem-dữ-liệu-bằng-vs-code)
- [Bước 10 — Cài pre-commit](#bước-10--cài-pre-commit)
- [Bước 11 — Lệnh dùng hằng ngày](#bước-11--lệnh-dùng-hằng-ngày)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Bước 0 — Kiểm tra máy

| Yêu cầu | Tối thiểu | Ghi chú |
|---|---|---|
| RAM | 8 GB (khuyến nghị 16 GB) | SQL Server cần ~2 GB, 2 container Airflow ~1.5 GB |
| Ổ cứng trống | 15 GB | Các image Docker ~8–10 GB |
| CPU | 64-bit, bật ảo hóa (VT-x/AMD-V) | Windows: *Task Manager → Performance → CPU → Virtualization: Enabled* |
| Cổng trống | `1433` (SQL Server), `8080` (Airflow) | Sau này thêm `3000` (Grafana) |

Kiểm tra cổng có bị chiếm không:

```bash
# Linux / macOS
sudo lsof -i :1433 -i :8080

# Windows (PowerShell)
netstat -ano | findstr ":1433 :8080"
```

Không có kết quả = cổng trống ✅. Nếu có: tắt chương trình đó (thường gặp: SQL Server cài sẵn trên Windows, hoặc container cũ).

---

## Bước 1 — Cài công cụ

### 1.1. Docker

<details>
<summary><b>🪟 Windows</b></summary>

1. Bật WSL2: mở PowerShell **Run as Administrator** → `wsl --install` → khởi động lại máy.
2. Cài **Docker Desktop**: https://www.docker.com/products/docker-desktop (chọn **Use WSL 2**).
3. Docker Desktop → *Settings → Resources → WSL Integration* → bật cho Ubuntu.
4. **Mọi lệnh trong tài liệu này chạy trong terminal Ubuntu (WSL)**, không chạy trong PowerShell/CMD.

</details>

<details>
<summary><b>🍎 macOS</b></summary>

1. Cài **Docker Desktop** (đúng bản *Apple Silicon* hoặc *Intel*).
2. *Settings → Resources* → **Memory ≥ 6 GB**.
3. **Chip Apple (M1–M4):** *Settings → General* → bật **Use Rosetta for x86_64/amd64 emulation** (SQL Server chỉ có image amd64).

</details>

<details>
<summary><b>🐧 Linux (Ubuntu)</b></summary>

```bash
# Cài Docker Engine + Compose plugin: https://docs.docker.com/engine/install/ubuntu/
sudo usermod -aG docker $USER
newgrp docker        # hoặc đăng xuất rồi đăng nhập lại
```

</details>

Kiểm tra:

```bash
docker --version
docker compose version
docker run --rm hello-world       # thấy "Hello from Docker!" là được
```

> 📝 Tài liệu dùng lệnh **`docker compose`** (Compose v2). Máy chỉ có `docker-compose` (có gạch ngang) thì thay tương ứng.

### 1.2. Git

```bash
sudo apt update && sudo apt install -y git      # Ubuntu / WSL
xcode-select --install                           # macOS
```

Cấu hình (một lần):

```bash
git config --global user.name  "Họ Tên Của Bạn"
git config --global user.email "email-dung-cho-github@example.com"
git config --global init.defaultBranch main
git config --global core.autocrlf input      # tránh lỗi xuống dòng CRLF trên Windows
git config --global pull.rebase false
```

### 1.3. GitHub CLI

```bash
# Cài: https://cli.github.com   (Ubuntu: sudo apt install gh ; macOS: brew install gh)
gh auth login        # GitHub.com → SSH → tạo khóa mới → đăng nhập bằng trình duyệt
gh auth status
```

### 1.4. VS Code + extension

Cài VS Code: https://code.visualstudio.com (Windows: cài thêm extension **WSL**, mở dự án bằng `code .` từ terminal Ubuntu).

```bash
code --install-extension ms-python.python
code --install-extension ms-python.black-formatter
code --install-extension ms-python.flake8
code --install-extension redhat.vscode-yaml
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-mssql.mssql
code --install-extension github.vscode-github-actions
code --install-extension innoverio.vscode-dbt-power-user
```

### 1.5. Python + pre-commit

dbt và Airflow chạy **trong container**, nhưng pre-commit (kiểm tra code khi commit) chạy **trên máy**:

```bash
python3 --version                 # cần >= 3.9
sudo apt install -y python3-pip python3-venv pipx    # Ubuntu / WSL  (macOS: brew install pipx)
pipx ensurepath                   # mở terminal mới sau lệnh này
pipx install pre-commit
pre-commit --version
```

---

## Bước 2 — Lấy mã nguồn

```bash
cd ~                              # Windows: thư mục trong WSL, KHÔNG dùng /mnt/c/...
git clone git@github.com:farols1505/dbt-airflow-dataops.git dbt_airflow_project
cd dbt_airflow_project
git branch --show-current         # develop (nhánh mặc định)
```

> Tên container được cố định trong `docker-compose.yml` (`name: dbt_airflow_project`), nên tên thư mục không bắt buộc. Vẫn nên đặt `dbt_airflow_project` cho thống nhất với tài liệu.

---

## Bước 3 — Tạo file `.env`

`docker-compose.yml` đọc mọi mật khẩu từ file `.env`. Thiếu file này thì **không container nào chạy được**.

```bash
cp .env.example .env

# Sinh khóa Fernet cho Airflow
sed -i "s|^AIRFLOW_FERNET_KEY=.*|AIRFLOW_FERNET_KEY=$(python3 -c 'import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())')|" .env

# Linux: GID của docker socket (Windows WSL / macOS: bỏ qua, giữ 0)
sed -i "s|^DOCKER_GID=.*|DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)|" .env
```

Mở `.env` và sửa:
- `DBT_ENV_SECRET_PASSWORD`, `POSTGRES_PASSWORD`: mật khẩu **chỉ gồm chữ và số**, có chữ hoa + chữ thường + số, ≥ 8 ký tự.
- `SA_PASSWORD`: máy mới hoàn toàn thì đặt mật khẩu mạnh tùy ý. Nếu máy **đã từng** chạy dự án (volume SQL Server cũ còn đó) thì **phải giữ mật khẩu cũ** (`YourStrong@Passw0rd`).

Kiểm tra `.env` bị Git bỏ qua:

```bash
git check-ignore -v .env          # phải in ra: .gitignore:2:.env   .env
```

---

## Bước 4 — Chuẩn bị riêng theo hệ điều hành

**🐧 Linux / 🪟 WSL:** cho container Airflow quyền ghi log:

```bash
chmod -R 777 airflow/logs
```

**🍎 macOS chip Apple:** build image dạng amd64:

```bash
echo 'export DOCKER_DEFAULT_PLATFORM=linux/amd64' >> ~/.zshrc
source ~/.zshrc
```

---

## Bước 5 — Build và khởi động các container

```bash
docker compose build              # lần đầu 10–20 phút
docker compose up -d
```

Đợi 2–3 phút, rồi:

```bash
docker compose ps
```

Mong đợi:

```
SERVICE             STATUS
airflow-scheduler   Up
airflow-webserver   Up (healthy)
dbt                 Up
postgres            Up (healthy)
sqlserver           Up (healthy)
```

Có dịch vụ không `Up` → `docker compose logs <tên-service>` và tra [Lỗi thường gặp](#lỗi-thường-gặp).

---

## Bước 6 — Khởi tạo SQL Server

```bash
./scripts/init_sqlserver.sh
```

Script tự chờ SQL Server sẵn sàng, restore AdventureWorks (nếu chưa có) và tạo tài khoản dbt từ `.env`. Mong đợi:

```
⏳ [1/3] Chờ SQL Server sẵn sàng...
   ✅ SQL Server đã sẵn sàng
⏳ [2/3] Kiểm tra database AdventureWorks2014...
   Chưa có → đang restore từ /tmp/AdventureWorks2014.bak (khoảng 30 giây)...
   ✅ Đã restore AdventureWorks2014
⏳ [3/3] Tạo/cập nhật tài khoản dbt: dbt_user...
   ✅ Tài khoản dbt_user sẵn sàng (quyền db_owner trên AdventureWorks2014)
🎉 Khởi tạo SQL Server hoàn tất.
```

(Lần chạy sau sẽ báo `Đã có sẵn, bỏ qua restore`. Chạy bao nhiêu lần cũng được.)

---

## Bước 7 — Kiểm tra dbt

```bash
docker compose exec dbt dbt deps
docker compose exec dbt dbt debug
```

- `dbt deps` có thể in `Updated version available` cho `dbt_utils`. Đó **không phải lỗi**.
- `dbt debug`: trong phần `Connection:` phải có `schema: dev`, `UID: dbt_user`, `Connection test: [OK connection ok]`, cuối cùng `All checks passed!`.

```bash
docker compose exec dbt dbt build        # = dbt run + dbt test theo thứ tự phụ thuộc
```

Phần cuối output phải có `ERROR=0`. Với model gốc (trước file `04`): `Done. PASS=28 WARN=0 ERROR=0 SKIP=0 TOTAL=28`. Con số này tăng dần khi bạn thêm model/test ở file `04`, `05`.

---

## Bước 8 — Kiểm tra Airflow

1. Mở **http://localhost:8080**, đăng nhập `admin` / mật khẩu `AIRFLOW_ADMIN_PASSWORD` trong `.env`.
2. Trang **DAGs** phải hiện DAG (trước file `06`: `dbt_transform`; sau file `06`: `dbt_pipeline`). Có thông báo đỏ *"Broken DAG"* → bấm vào để xem lỗi.
3. DAG mới tạo luôn ở trạng thái **tắt (paused)**, và DAG tắt thì Trigger sẽ không chạy. → **Gạt công tắc bên trái tên DAG sang bật**, rồi bấm ▶ **Trigger DAG**.
4. Bấm tên DAG → tab **Grid** → đợi 1–2 phút: mọi ô 🟩 xanh. Ô 🟥/🟧 → bấm vào → **Logs**.
5. DAG gốc `dbt_transform` chạy **mỗi 5 phút** → kiểm tra xong thì **tắt lại**.

---

## Bước 9 — Xem dữ liệu bằng VS Code

Dùng extension **SQL Server (mssql)** (Azure Data Studio đã bị Microsoft ngừng phát triển).

1. VS Code → thanh bên trái → biểu tượng **SQL Server** → **Add Connection**:

   | Trường | Giá trị |
   |---|---|
   | Server | `localhost,1433` |
   | Authentication | SQL Login |
   | User / Password | `sa` / `SA_PASSWORD` trong `.env` (hoặc `dbt_user` / `DBT_ENV_SECRET_PASSWORD`) |
   | Database | `AdventureWorks2014` |
   | Trust server certificate | ✅ Yes |

2. Mở [`hand_on.sql`](../hand_on.sql) → chuột phải → **Execute Query** để xem các bảng nguồn.
3. Kết quả của dbt nằm trong schema theo môi trường: **`dev_bronze`**, **`dev_silver`**, **`dev_gold`** (target `prod` → `prod_*`...):

   ```sql
   SELECT TOP 10 * FROM dev_gold.gld_sales_summary ORDER BY order_date DESC;
   ```

---

## Bước 10 — Cài pre-commit

```bash
pre-commit install                # cài hook vào .git/hooks (mỗi lần clone phải chạy lại)
pre-commit run --all-files        # lần đầu tải công cụ 2–5 phút; mọi hook phải Passed
```

---

## Bước 11 — Lệnh dùng hằng ngày

| Việc | Lệnh |
|---|---|
| Bật hệ thống | `docker compose up -d` |
| Tắt hệ thống (giữ dữ liệu) | `docker compose stop` |
| Xem trạng thái | `docker compose ps` |
| Xem log một dịch vụ | `docker compose logs -f airflow-scheduler` (Ctrl+C để thoát) |
| Chạy lệnh dbt | `docker compose exec dbt dbt <lệnh>` |
| Chạy dbt cho môi trường khác | `docker compose exec dbt dbt build --target prod` |
| Vào shell container dbt | `docker compose exec dbt bash` |
| Sau khi sửa `.env` | `docker compose up -d` (Compose tự tạo lại container bị ảnh hưởng) |
| Sau khi sửa Dockerfile/requirements | `docker compose build <dịch-vụ> && docker compose up -d` |

> 🛑 **CẨN THẬN** với `docker compose down -v`: **xóa volume** → mất database AdventureWorks và lịch sử Airflow. Sau đó phải chạy lại Bước 6.

> 💡 Các container có `restart: unless-stopped` → tự bật lại khi khởi động máy. Không dùng thì `docker compose stop` để giải phóng RAM.

---

## Checklist hoàn thành

- [ ] `docker run --rm hello-world` chạy được
- [ ] Git đã cấu hình `user.name`, `user.email`, `core.autocrlf input`; `gh auth status` OK
- [ ] VS Code + extension đã cài
- [ ] `.env` đã tạo, có khóa Fernet, bị Git bỏ qua
- [ ] `docker compose ps`: `sqlserver`, `postgres`, `airflow-webserver` `(healthy)`; `dbt`, `airflow-scheduler` `Up`
- [ ] `./scripts/init_sqlserver.sh` thành công
- [ ] `dbt debug` → `UID: dbt_user`, `schema: dev`, `All checks passed!`
- [ ] `dbt build` → `ERROR=0`
- [ ] Airflow đăng nhập được, DAG chạy 🟩, đã tắt lại DAG chạy 5 phút
- [ ] Xem được `dev_gold.*` từ VS Code
- [ ] `pre-commit run --all-files`: mọi hook `Passed`

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `required variable SA_PASSWORD is missing a value` | Chưa có `.env` | Bước 3 |
| `Bind for 127.0.0.1:1433 failed: port is already allocated` | Cổng 1433 đang bị chiếm | Tắt SQL Server cài sẵn / container cũ (`docker ps` → `docker stop ...`) |
| `sqlserver` dừng `Exited (137)` hoặc log `requires at least 2000 megabytes` | Thiếu RAM | Tăng RAM cho Docker (≥ 6 GB), tắt bớt ứng dụng |
| `sqlserver` không `healthy`, log có `Login failed for user 'sa'` | `SA_PASSWORD` khác mật khẩu lúc volume được tạo | Đặt lại mật khẩu cũ trong `.env` → `docker compose up -d` |
| `/bin/bash^M: bad interpreter` | File `.sh` bị đổi sang CRLF (Windows) | `git config --global core.autocrlf input`, clone lại |
| Script dừng ở bước 1 (`SQL Server không phản hồi`) | SQL Server chưa lên / sai mật khẩu sa | `docker compose logs sqlserver` |
| `Password validation failed` khi tạo login | Mật khẩu dbt quá yếu | ≥ 8 ký tự, có hoa + thường + số |
| `dbt debug`: `Env var required but not provided: 'DBT_USER'` | Container dbt tạo trước khi có `.env` | `docker compose up -d --force-recreate dbt` |
| `dbt debug`: `Login failed for user 'dbt_user'` | Chưa chạy script, hoặc vừa đổi mật khẩu | `./scripts/init_sqlserver.sh` → `docker compose up -d --force-recreate dbt` |
| `airflow-webserver` không `healthy`; log có `InvalidToken`/`Fernet` hoặc `password authentication failed for user "airflow"` | Volume Postgres cũ tạo bằng khóa/mật khẩu khác | `docker compose down` → `docker volume rm dbt_airflow_project_postgres_data` → `docker compose up -d` (chỉ mất lịch sử Airflow) |
| Task Airflow lỗi `permission denied ... docker.sock` | `DOCKER_GID` sai | `stat -c '%g' /var/run/docker.sock` → sửa `.env` → `docker compose up -d` |
| Airflow log lỗi `Permission denied: '/opt/airflow/logs/...'` | Container không ghi được log | `chmod -R 777 airflow/logs` |
| Trigger DAG nhưng đứng mãi ở *queued* | DAG đang tắt | Gạt công tắc bật DAG |
| Mac chip Apple: build lỗi `msodbcsql17` / `exec format error` | Image build dạng ARM | Bước 4 phần macOS, rồi `docker compose build --no-cache` |
| `./scripts/init_sqlserver.sh: Permission denied` | Mất quyền thực thi | `bash scripts/init_sqlserver.sh` |
| Muốn làm lại từ đầu | | `docker compose down -v` → `docker compose build --no-cache` → Bước 5 |

Gặp lỗi mới → ghi lại (hiện tượng, nguyên nhân, cách sửa) để đưa vào `docs/TROUBLESHOOTING.md` ở file `09`.

---

## Tiếp theo

→ Máy chính: đã xong `01`, `02` → sang **`03_CI_VA_DEPLOY_CO_BAN.md`**.
→ Máy mới (vd. máy demo): xong file này là đủ, không cần làm lại `02`.
