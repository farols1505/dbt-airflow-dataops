# 01 — CHUẨN BỊ MÔI TRƯỜNG

| | |
|---|---|
| **Ai làm** | **Cả 3 thành viên** (A, B, C), mỗi người trên máy của mình |
| **Khi nào** | Ngày 1–2 của dự án |
| **Thời gian** | 1–2 giờ (phần lớn là chờ tải và build image) |
| **Kết quả** | Máy của bạn chạy được toàn bộ pipeline **gốc**: SQL Server có dữ liệu, `dbt run`/`dbt test` thành công, Airflow UI mở được |
| **Tài liệu trước** | [`00_TONG_QUAN_DU_AN.md`](00_TONG_QUAN_DU_AN.md) |

> 💡 Ở bước này **chưa sửa code gì cả**. Mục tiêu duy nhất: chứng minh máy bạn chạy được hệ thống. Mọi thay đổi bắt đầu từ file `02_...` trở đi.

---

## Mục lục

- [Bước 0 — Kiểm tra máy](#bước-0--kiểm-tra-máy)
- [Bước 1 — Cài công cụ](#bước-1--cài-công-cụ)
- [Bước 2 — Lấy mã nguồn](#bước-2--lấy-mã-nguồn)
- [Bước 3 — Chuẩn bị riêng theo hệ điều hành](#bước-3--chuẩn-bị-riêng-theo-hệ-điều-hành)
- [Bước 4 — Build và khởi động các container](#bước-4--build-và-khởi-động-các-container)
- [Bước 5 — Restore database AdventureWorks](#bước-5--restore-database-adventureworks)
- [Bước 6 — Tạo tài khoản SQL cho dbt](#bước-6--tạo-tài-khoản-sql-cho-dbt)
- [Bước 7 — Kiểm tra dbt](#bước-7--kiểm-tra-dbt)
- [Bước 8 — Kiểm tra Airflow](#bước-8--kiểm-tra-airflow)
- [Bước 9 — Xem dữ liệu bằng VS Code](#bước-9--xem-dữ-liệu-bằng-vs-code)
- [Bước 10 — Lệnh dùng hằng ngày](#bước-10--lệnh-dùng-hằng-ngày)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)
- [Tiếp theo làm gì?](#tiếp-theo-làm-gì)

---

## Bước 0 — Kiểm tra máy

| Yêu cầu | Tối thiểu | Ghi chú |
|---|---|---|
| RAM | 8 GB (khuyến nghị 16 GB) | SQL Server cần ~2 GB, 2 container Airflow ~1.5 GB |
| Ổ cứng trống | 15 GB | Các image Docker ~8–10 GB |
| CPU | 64-bit, bật ảo hóa (VT-x/AMD-V) | Windows: kiểm tra *Task Manager → Performance → CPU → Virtualization: Enabled* |
| Cổng trống | `1433` (SQL Server), `8080` (Airflow) | Sau này thêm `3000` (Grafana) |

Kiểm tra cổng có bị chiếm không:

```bash
# Linux / macOS
sudo lsof -i :1433 -i :8080

# Windows (PowerShell)
netstat -ano | findstr ":1433 :8080"
```

Không có kết quả = cổng trống ✅. Nếu có: tắt chương trình đó (thường gặp: SQL Server cài sẵn trên Windows, hoặc một container cũ).

---

## Bước 1 — Cài công cụ

### 1.1. Docker

<details>
<summary><b>🪟 Windows</b></summary>

1. Bật WSL2: mở PowerShell **Run as Administrator**:
   ```powershell
   wsl --install
   ```
   Khởi động lại máy.
2. Cài **Docker Desktop**: https://www.docker.com/products/docker-desktop
   - Khi cài, chọn **Use WSL 2 instead of Hyper-V**.
3. Docker Desktop → *Settings → Resources → WSL Integration* → bật cho distro Ubuntu.
4. **Từ giờ, mọi lệnh trong tài liệu này chạy trong terminal Ubuntu (WSL)**, không chạy trong PowerShell/CMD.

</details>

<details>
<summary><b>🍎 macOS</b></summary>

1. Cài **Docker Desktop**: https://www.docker.com/products/docker-desktop (chọn đúng bản *Apple Silicon* hoặc *Intel*).
2. Docker Desktop → *Settings → Resources* → **Memory ≥ 6 GB**.
3. **Máy chip Apple (M1/M2/M3/M4):** *Settings → General* → bật **Use Rosetta for x86_64/amd64 emulation on Apple Silicon**. (SQL Server chỉ có image amd64.)

</details>

<details>
<summary><b>🐧 Linux (Ubuntu)</b></summary>

```bash
# Cài Docker Engine + Compose plugin theo hướng dẫn chính thức:
# https://docs.docker.com/engine/install/ubuntu/
# Sau khi cài, cho phép user hiện tại dùng docker không cần sudo:
sudo usermod -aG docker $USER
newgrp docker        # hoặc đăng xuất rồi đăng nhập lại
```

</details>

Kiểm tra:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

Thấy dòng `Hello from Docker!` là được ✅.

> 📝 Tài liệu này dùng lệnh **`docker compose`** (có dấu cách, Compose v2). Nếu máy bạn chỉ có `docker-compose` (có gạch ngang) thì thay tương ứng, kết quả như nhau.

### 1.2. Git

```bash
# Windows (trong WSL) / Linux
sudo apt update && sudo apt install -y git
# macOS
xcode-select --install
```

Cấu hình (làm **một lần**):

```bash
git config --global user.name  "Họ Tên Của Bạn"
git config --global user.email "email-dung-cho-github@example.com"
git config --global init.defaultBranch main
git config --global core.autocrlf input      # QUAN TRỌNG với Windows: tránh lỗi xuống dòng CRLF
git config --global pull.rebase false
```

> ⚠️ **Vì sao cần `core.autocrlf input`?** File `sqlserver/restore_db.sh` nếu bị đổi sang kiểu xuống dòng Windows (CRLF) sẽ báo lỗi `/bin/bash^M: bad interpreter` và database không restore được.

### 1.3. Tài khoản GitHub

1. Tạo tài khoản tại https://github.com (nếu chưa có). **Gửi username GitHub cho trưởng nhóm** để được mời vào repo.
2. Đăng nhập GitHub từ máy (chọn **một** trong hai cách):

**Cách 1 — GitHub CLI (khuyến nghị, trưởng nhóm bắt buộc dùng cách này):**
```bash
# Cài: https://cli.github.com  (Ubuntu: sudo apt install gh ; macOS: brew install gh)
gh auth login        # chọn GitHub.com → SSH → tạo khóa mới → đăng nhập bằng trình duyệt
gh auth status       # kiểm tra
```

**Cách 2 — SSH key thủ công:**
```bash
ssh-keygen -t ed25519 -C "email-dung-cho-github@example.com"
cat ~/.ssh/id_ed25519.pub     # copy nội dung → GitHub → Settings → SSH and GPG keys → New SSH key
ssh -T git@github.com         # thấy "Hi <username>!" là được
```

### 1.4. VS Code + extension

Cài VS Code: https://code.visualstudio.com (Windows: cài thêm extension **WSL** và mở thư mục dự án bằng lệnh `code .` từ terminal Ubuntu).

Cài các extension cần cho dự án:

```bash
code --install-extension ms-python.python
code --install-extension ms-python.black-formatter
code --install-extension ms-python.flake8
code --install-extension redhat.vscode-yaml
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-mssql.mssql
code --install-extension github.vscode-github-actions
code --install-extension innoverio.vscode-dbt-power-user   # khuyến nghị cho B
```

### 1.5. Python trên máy (dùng từ file 02 cho pre-commit, black, sqlfluff)

dbt và Airflow chạy **trong container**, nhưng các công cụ kiểm tra code (pre-commit) chạy **trên máy bạn**, nên cần Python ≥ 3.9 và `pipx`:

```bash
python3 --version                 # cần >= 3.9

# Ubuntu / WSL
sudo apt install -y python3-pip python3-venv pipx
# macOS
brew install pipx

pipx ensurepath                   # mở terminal mới sau lệnh này
pipx install pre-commit
pre-commit --version
```

---

## Bước 2 — Lấy mã nguồn

**Trưởng nhóm (A):** bạn đã có mã nguồn trên máy → bỏ qua bước này. Hãy làm sớm phần *tạo repo GitHub* (file `02_...`) để gửi link cho B và C.

**B và C:**

- **Nếu A đã gửi link repo:**
  ```bash
  cd ~                                      # Windows: phải là thư mục trong WSL, KHÔNG dùng /mnt/c/...
  git clone git@github.com:<tai-khoan-A>/<ten-repo>.git dbt_airflow_project
  cd dbt_airflow_project
  ```
- **Nếu A chưa tạo repo:** nhận file zip từ A, giải nén vào `~/dbt_airflow_project`.

> ⚠️ **Thư mục BẮT BUỘC tên là `dbt_airflow_project`** (chú ý tham số cuối trong lệnh `git clone`).
> Docker đặt tên container theo tên thư mục, ví dụ `dbt_airflow_project-dbt-1`, và DAG Airflow gọi đúng tên container này. Đặt tên thư mục khác → DAG lỗi *"No such container"*.
> (Trưởng nhóm sẽ sửa triệt để ở file `02_...` bằng cách cố định tên project trong `docker-compose.yml`.)

> ⚠️ **Windows:** clone vào thư mục **trong WSL** (`~/...`). Đặt trong `/mnt/c/...` sẽ chậm và dễ lỗi quyền truy cập.

---

## Bước 3 — Chuẩn bị riêng theo hệ điều hành

Chạy tại thư mục gốc dự án (`dbt_airflow_project/`).

**Mọi hệ điều hành:** tạo các thư mục Git không lưu (thư mục rỗng):

```bash
mkdir -p airflow/plugins airflow/logs
```

> Thiếu `airflow/plugins` → build Airflow lỗi `failed to compute cache key ... /plugins: not found`.

**🐧 Linux / 🪟 WSL:** cho container Airflow (chạy bằng user khác) quyền ghi log:

```bash
chmod -R 777 airflow/logs
```

**🍎 macOS chip Apple:** ép Docker build image dạng amd64 (driver SQL Server không hỗ trợ ARM trong cấu hình này):

```bash
echo 'export DOCKER_DEFAULT_PLATFORM=linux/amd64' >> ~/.zshrc
source ~/.zshrc
```

---

## Bước 4 — Build và khởi động các container

```bash
# Build image (lần đầu mất 10–20 phút; máy Mac chip Apple có thể lâu hơn)
docker compose build

# Khởi động 5 container ở chế độ chạy nền
docker compose up -d
```

> **Trưởng nhóm (A):** máy bạn đã build từ trước và các container đang ở trạng thái *Exited*. Chỉ cần chạy `docker compose up -d`, **không** cần build lại.

Đợi **1–2 phút**, rồi kiểm tra:

```bash
docker compose ps
```

Kết quả mong đợi: 5 dịch vụ đều ở trạng thái `running` / `Up`:

```
NAME                                     SERVICE             STATUS
dbt_airflow_project-airflow-scheduler-1  airflow-scheduler   Up
dbt_airflow_project-airflow-webserver-1  airflow-webserver   Up
dbt_airflow_project-dbt-1                dbt                 Up
dbt_airflow_project-postgres-1           postgres            Up (healthy)
dbt_airflow_project-sqlserver-1          sqlserver           Up
```

Có dịch vụ không `Up` → xem log: `docker compose logs <tên-service>` và tra [Lỗi thường gặp](#lỗi-thường-gặp).

---

## Bước 5 — Restore database AdventureWorks

File backup `AdventureWorks2014.bak` đã được tải sẵn vào image SQL Server lúc build. Giờ restore nó:

```bash
docker compose exec sqlserver /tmp/restore_db.sh
```

Script chờ 20 giây rồi restore. Kết quả cuối phải có dòng:

```
RESTORE DATABASE successfully processed ... pages in ... seconds
```

Kiểm tra:

```bash
docker compose exec sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourStrong@Passw0rd' \
  -Q "SELECT name FROM sys.databases"
```

Danh sách phải có `AdventureWorks2014` ✅.

> 📝 Database nằm trong Docker volume `sqlserver_data`, nên **chỉ cần restore một lần**. Tắt/bật container không mất dữ liệu. Chỉ khi chạy `docker compose down -v` (xóa volume) mới phải restore lại.
>
> Nếu đã restore rồi mà chạy lại, sẽ báo lỗi *"database already exists"*. Đó là bình thường, bỏ qua.

---

## Bước 6 — Tạo tài khoản SQL cho dbt

dbt không dùng tài khoản `sa` mà dùng tài khoản riêng (đang khai báo trong `dbt/profiles.yml`):

```bash
docker compose exec sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourStrong@Passw0rd' \
  -Q "CREATE LOGIN imrandbtnew WITH PASSWORD = 'Imran@12345'; USE AdventureWorks2014; CREATE USER imrandbtnew FOR LOGIN imrandbtnew; ALTER ROLE db_owner ADD MEMBER imrandbtnew;"
```

Kiểm tra:

```bash
docker compose exec sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'YourStrong@Passw0rd' \
  -Q "SELECT name FROM sys.sql_logins WHERE type = 'S'"
```

Danh sách có `imrandbtnew` ✅. (Báo lỗi *"already exists"* = đã tạo trước đó, bỏ qua.)

> 🔐 Mật khẩu này là mật khẩu mẫu của giáo viên, chỉ dùng trên máy local. Ở file `02_...`, trưởng nhóm sẽ chuyển toàn bộ mật khẩu sang biến môi trường (`.env`) trước khi đưa code lên repo public.

---

## Bước 7 — Kiểm tra dbt

Chạy lần lượt:

```bash
# 1. Cài package dbt (dbt_utils)
docker compose exec dbt dbt deps

# 2. Kiểm tra kết nối
docker compose exec dbt dbt debug
```

`dbt debug` phải kết thúc bằng:

```
Connection test: [OK connection ok]
All checks passed!
```

```bash
# 3. Chạy các model
docker compose exec dbt dbt run
```

Kết quả mong đợi — **phần đầu** output có dòng:

```
Found 10 models, 18 data tests, 13 sources, ...
```

và **phần cuối** output trông như sau (giờ và số giây sẽ khác trên máy bạn):

```
11:20:54  Finished running 4 view models, 6 table models in 0 hours 0 minutes and 1.30 seconds (1.30s).
11:20:54
11:20:54  Completed successfully
11:20:54
11:20:54  Done. PASS=10 WARN=0 ERROR=0 SKIP=0 TOTAL=10
```

✅ Điều cần kiểm tra: **`PASS=10` và `ERROR=0`**. 4 view = tầng bronze, 6 table = tầng silver + gold.

```bash
# 4. Chạy test
docker compose exec dbt dbt test
```

Kết quả mong đợi — **phần cuối** output:

```
Completed successfully

Done. PASS=18 WARN=0 ERROR=0 SKIP=0 TOTAL=18
```

✅ Điều cần kiểm tra: **`PASS=18` và `ERROR=0`**.

> 📝 Số lượng (10 model, 18 test) đúng với **mã nguồn gốc**. Sau khi B sửa model ở file `03_...`, các con số này sẽ thay đổi.

---

## Bước 8 — Kiểm tra Airflow

1. Mở trình duyệt: **http://localhost:8080**
2. Đăng nhập: **Username `admin` / Password `admin`**
   (Lưu ý: `1. README.md` ghi `airflow/airflow` là **sai**. Tài khoản đúng được tạo tự động trong `docker-compose.yml` là `admin/admin`.)
3. Trang **DAGs** phải hiện DAG **`dbt_transform`**.
   - Phía trên có thông báo đỏ *"Broken DAG"* → xem [Lỗi thường gặp](#lỗi-thường-gặp).
4. Chạy thử: nếu DAG đang **tắt** (công tắc bên trái tên DAG màu xám), **gạt sang bật** trước. DAG đang tắt thì Trigger sẽ không chạy, chỉ đứng ở trạng thái *queued*. Sau đó bấm nút ▶ (**Trigger DAG**) bên phải DAG `dbt_transform`.
5. Bấm vào tên DAG → tab **Grid** → đợi 1–2 phút. Ô của task `dbt_run`, `dbt_test`:
   - 🟩 xanh lá = thành công
   - 🟥 đỏ / 🟧 cam (*up_for_retry*) = lỗi → bấm vào ô → **Logs** để xem lý do

> ⚠️ **Sau khi kiểm tra xong, hãy TẮT (Pause) DAG `dbt_transform`** (gạt công tắc bên trái tên DAG). DAG gốc chạy **mỗi 5 phút**, để bật sẽ tốn tài nguyên và làm rối log. C sẽ thay bằng DAG mới chạy hằng ngày ở file `05_...`.

### ⚠️ Lỗi đã biết trên Linux: `permission denied ... docker.sock`

Trên **Linux** (kể cả máy của trưởng nhóm), task có thể lỗi với log:

```
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
```

**Nguyên nhân:** DAG gọi `docker exec` từ trong container Airflow. User `airflow` trong container không thuộc nhóm `docker` **của máy host** (hai bên khác mã nhóm GID).
**Sửa triệt để:** trưởng nhóm sẽ sửa trong `docker-compose.yml` ở file `02_...` (thêm `group_add`).
**Tạm thời để kiểm tra ngay (chỉ trên máy mình, không commit):**

```bash
# 1. Lấy mã nhóm (GID) của docker socket trên máy host
stat -c '%g' /var/run/docker.sock          # ví dụ in ra: 127

# 2. Tạo file override cục bộ (Docker Compose tự đọc file này)
cat > docker-compose.override.yml <<'EOF'
services:
  airflow-webserver:
    group_add: ["127"]      # thay 127 bằng số ở bước 1
  airflow-scheduler:
    group_add: ["127"]
EOF

# 3. Khởi động lại 2 container Airflow
docker compose up -d airflow-webserver airflow-scheduler
```

Trigger lại DAG. Task phải 🟩 xanh. Khi A đã sửa xong ở file `02_...`, **xóa** file `docker-compose.override.yml` này đi.

> Trên Docker Desktop (Windows/macOS) thường **không** gặp lỗi này. Nếu vẫn gặp, báo trưởng nhóm.

---

## Bước 9 — Xem dữ liệu bằng VS Code

Dùng extension **SQL Server (mssql)** đã cài ở bước 1.4 (Azure Data Studio mà tài liệu gốc nhắc tới đã bị Microsoft ngừng phát triển).

1. VS Code → thanh bên trái → biểu tượng **SQL Server** → **Add Connection**.
2. Nhập:

   | Trường | Giá trị |
   |---|---|
   | Server | `localhost,1433` |
   | Authentication | SQL Login |
   | User | `sa` |
   | Password | `YourStrong@Passw0rd` |
   | Database | `AdventureWorks2014` |
   | Trust server certificate | ✅ Yes |

3. Mở file [`hand_on.sql`](../hand_on.sql) ở thư mục gốc → chuột phải → **Execute Query**. Bạn sẽ thấy danh sách schema, bảng, khách hàng, đơn hàng, sản phẩm.
4. Xem kết quả của dbt: với mã nguồn gốc, các bảng/view nằm trong schema **`bronze`**, **`silver`**, **`gold`**:

   ```sql
   SELECT TOP 10 * FROM gold.gld_sales_summary ORDER BY order_date DESC;
   ```

   (Sau file `02_...`, mỗi môi trường có schema riêng: `dev_bronze`, `dev_silver`, `dev_gold`...)

> **B nên dành thêm thời gian ở bước này**: tìm hiểu các bảng `Sales.SalesOrderHeader`, `Sales.SalesOrderDetail`, `Sales.Customer`, `Person.Person`, `Production.Product`, `Production.ProductSubcategory`, `Production.ProductCategory` (cột nào là khóa, cột nào có NULL, giá trị `Status` gồm những gì). Đây là đầu vào cho file `03_...` và `04_...`.

---

## Bước 10 — Lệnh dùng hằng ngày

Chạy tại thư mục gốc dự án:

| Việc | Lệnh |
|---|---|
| Bật hệ thống | `docker compose up -d` |
| Tắt hệ thống (giữ nguyên dữ liệu) | `docker compose stop` |
| Xem trạng thái | `docker compose ps` |
| Xem log một dịch vụ | `docker compose logs -f airflow-scheduler` (Ctrl+C để thoát) |
| Chạy lệnh dbt | `docker compose exec dbt dbt <lệnh>` |
| Vào shell container dbt | `docker compose exec dbt bash` |
| Khởi động lại một dịch vụ | `docker compose restart airflow-webserver` |
| Build lại sau khi sửa Dockerfile/requirements | `docker compose build <dịch-vụ> && docker compose up -d` |

> 🛑 **CẨN THẬN** với `docker compose down -v`: lệnh này **xóa volume**, tức là **mất database** và lịch sử Airflow. Sau đó phải làm lại Bước 5 và 6. Chỉ dùng khi muốn làm lại từ đầu.

> 💡 Không dùng thì tắt hệ thống (`docker compose stop`) để giải phóng RAM.

---

## Checklist hoàn thành

Đánh dấu từng mục. Khi xong **hết**, chụp màn hình kết quả `dbt test` + trang Grid của Airflow, gửi vào nhóm chat.

- [ ] `docker run --rm hello-world` chạy được
- [ ] Git đã cấu hình `user.name`, `user.email`, `core.autocrlf input`
- [ ] Đăng nhập GitHub từ máy được (`gh auth status` hoặc `ssh -T git@github.com`)
- [ ] Đã gửi username GitHub cho trưởng nhóm
- [ ] VS Code + các extension đã cài
- [ ] `pre-commit --version` chạy được
- [ ] Thư mục dự án tên đúng là `dbt_airflow_project`
- [ ] `docker compose ps`: 5 dịch vụ `Up`
- [ ] Database `AdventureWorks2014` đã restore
- [ ] Login `imrandbtnew` đã tạo
- [ ] `dbt debug` → `All checks passed!`
- [ ] `dbt run` → `PASS=10`
- [ ] `dbt test` → `PASS=18`
- [ ] Airflow UI đăng nhập được, thấy DAG `dbt_transform`, chạy thử 🟩 (hoặc đã ghi nhận lỗi docker.sock trên Linux)
- [ ] Đã **Pause** DAG `dbt_transform`
- [ ] Kết nối SQL Server từ VS Code, chạy được `hand_on.sql`

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `Bind for 0.0.0.0:1433 failed: port is already allocated` | Cổng 1433 đang bị chiếm (SQL Server cài sẵn trên máy, hoặc container cũ) | Tắt dịch vụ đó (Windows: *Services → SQL Server (MSSQLSERVER) → Stop*), hoặc `docker ps` → `docker stop <container>` |
| Tương tự với cổng `8080` | Chương trình khác dùng 8080 | Tắt chương trình đó |
| Container `sqlserver` dừng với `Exited (137)` | Thiếu RAM (bị hệ điều hành kill) | Tăng RAM cho Docker Desktop (≥ 6 GB), tắt bớt ứng dụng |
| `sqlserver` log báo `The SQL Server process ... requires at least 2000 megabytes` | Thiếu RAM | Như trên |
| `/bin/bash^M: bad interpreter` khi restore | File `.sh` bị đổi sang CRLF (Windows) | `git config --global core.autocrlf input`, xóa thư mục, clone lại, rồi `docker compose build --no-cache sqlserver` |
| `failed to compute cache key ... /plugins: not found` khi build | Thiếu thư mục `airflow/plugins` | `mkdir -p airflow/plugins` rồi build lại |
| Restore báo lỗi kết nối / `Login timeout expired` | SQL Server chưa khởi động xong | Đợi thêm 1 phút, chạy lại Bước 5 |
| `dbt debug` báo `Login failed for user 'imrandbtnew'` | Chưa làm Bước 6, hoặc Bước 5 chưa thành công | Làm lại Bước 5 → Bước 6 |
| `dbt debug` báo `Cannot open database "AdventureWorks2014"` | Chưa restore | Làm Bước 5 |
| Airflow UI không mở được | Webserver chưa khởi động xong (lần đầu khá lâu) | Đợi 2–3 phút; xem `docker compose logs -f airflow-webserver` |
| Airflow báo **Broken DAG** | Lỗi cú pháp/import trong file DAG | Bấm vào thông báo đỏ để xem chi tiết |
| Task lỗi `permission denied ... docker.sock` | Lỗi đã biết trên Linux | Xem phần *"Lỗi đã biết trên Linux"* cuối [Bước 8](#bước-8--kiểm-tra-airflow) |
| Task lỗi `No such container: dbt_airflow_project-dbt-1` | Thư mục dự án không tên `dbt_airflow_project` | Đổi tên thư mục, `docker compose down` rồi `docker compose up -d` |
| Airflow log lỗi `Permission denied: '/opt/airflow/logs/...'` | Container không ghi được vào `airflow/logs` | `chmod -R 777 airflow/logs` |
| Mac chip Apple: build lỗi `msodbcsql17` / `exec format error` | Image build dạng ARM | Làm phần macOS ở Bước 3, rồi `docker compose build --no-cache` |
| Mọi thứ rối tung, muốn làm lại từ đầu | | `docker compose down -v` → `docker compose build --no-cache` → làm lại từ Bước 4 |

Gặp lỗi mới không có trong bảng? **Ghi lại** (hiện tượng, nguyên nhân, cách sửa) và gửi C để đưa vào `docs/TROUBLESHOOTING.md` sau này.

---

## Tiếp theo làm gì?

| Thành viên | Việc tiếp theo |
|---|---|
| **A (trưởng nhóm)** | → `02_GIT_GITHUB_VA_NEN_TANG.md`: tạo repo public, nhánh, `.env`, sửa `docker-compose.yml` (gồm lỗi docker.sock), pre-commit. **Ưu tiên tạo repo và gửi link cho B, C sớm nhất có thể.** |
| **B** | Trong lúc chờ A: tìm hiểu kỹ dữ liệu (Bước 9), đọc các model trong `dbt/models/`. Khi A xong file 02 → `03_DBT_MODELS.md` |
| **C** | Trong lúc chờ A: đọc DAG cũ `airflow/dags/dbt_dag.py`, tạo một server Discord cho nhóm. Khi A xong file 02 → `05_AIRFLOW_DAG.md` |
