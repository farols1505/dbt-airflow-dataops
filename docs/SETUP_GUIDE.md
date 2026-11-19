# Hướng dẫn cài đặt (cho người mới)

Mục tiêu: từ máy trống đến pipeline chạy được trong **khoảng 30 phút** (chưa tính thời gian tải image lần đầu).

## 1. Yêu cầu

| | Tối thiểu |
|---|---|
| RAM | 8 GB (khuyến nghị 16 GB) |
| Ổ cứng trống | 15 GB |
| Phần mềm | Docker + Docker Compose v2, Git, Python ≥ 3.9 |
| Cổng trống | 1433, 8080 (và 3000 nếu dùng Grafana) |

- **Windows:** dùng WSL2 + Docker Desktop, chạy mọi lệnh trong terminal Ubuntu (WSL), clone vào thư mục trong WSL (không dùng `/mnt/c/...`).
- **macOS chip Apple:** bật *Use Rosetta* trong Docker Desktop và chạy `export DOCKER_DEFAULT_PLATFORM=linux/amd64` trước khi build.
- Cấu hình Git một lần: `git config --global core.autocrlf input`.

## 2. Lấy mã nguồn

```bash
git clone git@github.com:farols1505/dbt-airflow-dataops.git dbt_airflow_project
cd dbt_airflow_project
```

## 3. Tạo file `.env`

```bash
cp .env.example .env
sed -i "s|^AIRFLOW_FERNET_KEY=.*|AIRFLOW_FERNET_KEY=$(python3 -c 'import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())')|" .env
sed -i "s|^DOCKER_GID=.*|DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)|" .env   # chỉ Linux
```

Mở `.env`, đổi `DBT_ENV_SECRET_PASSWORD` và `POSTGRES_PASSWORD` thành mật khẩu **chỉ gồm chữ và số** (có chữ hoa, chữ thường, số, ≥ 8 ký tự). Linux/WSL: `chmod -R 777 airflow/logs`.

## 4. Khởi động

```bash
docker compose build             # lần đầu 10–20 phút
docker compose up -d
docker compose ps                # đợi sqlserver, postgres, airflow-webserver "(healthy)"
./scripts/init_sqlserver.sh      # restore AdventureWorks + tạo tài khoản dbt
```

## 5. Chạy dbt

```bash
docker compose exec dbt dbt deps
docker compose exec dbt dbt debug                     # All checks passed!
docker compose exec dbt dbt build --full-refresh      # cuối output: ERROR=0
```

## 6. Chạy Airflow

1. Mở http://localhost:8080, đăng nhập `admin` / `AIRFLOW_ADMIN_PASSWORD`.
2. DAG **`dbt_pipeline`** → gạt công tắc **bật** → ▶ **Trigger DAG**.
3. Tab **Grid**: mọi task chuyển 🟩 sau vài phút.

## 7. (Tùy chọn) Grafana và thông báo Discord

```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d grafana   # http://localhost:3000
```

Thông báo Discord: điền URL webhook vào `NOTIFY_WEBHOOK_URL` trong `.env` → `docker compose up -d`.

## 8. (Cho người phát triển) pre-commit

```bash
pipx install pre-commit
pre-commit install
```

Gặp lỗi: [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
