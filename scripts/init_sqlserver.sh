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
# Bất kỳ lệnh nào lỗi → in rõ dòng lỗi (thay vì thoát im lặng do set -e)
trap 'echo "❌ Lỗi ở dòng $LINENO (mã thoát $?). Xem log: docker compose logs sqlserver" >&2' ERR

cd "$(dirname "$0")/.."

# Đọc biến từ .env (nếu có). Trên GitHub Actions biến có thể đến từ Secrets.
if [[ -f .env ]]; then
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
# "| cat": Docker cài bằng snap không ghi được output thẳng vào file (vd. khi chạy
# script với "> log.txt") → luôn đi qua pipe; pipefail giữ nguyên mã thoát của sqlcmd.
run_sql() {
  local query="$1"
  docker compose exec -T sqlserver bash -c \
    '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -h -1 -W -Q "$1"' \
    _ "$query" | cat
}

echo "⏳ [1/3] Chờ SQL Server sẵn sàng..."
for i in $(seq 1 "$MAX_TRIES"); do
  if run_sql "SELECT 1" > /dev/null 2>&1; then
    echo "   ✅ SQL Server đã sẵn sàng"
    break
  fi
  if [[ "$i" -eq "$MAX_TRIES" ]]; then
    echo "   ❌ SQL Server không phản hồi. Xem log: docker compose logs sqlserver"
    exit 1
  fi
  sleep 5
done

echo "⏳ [2/3] Kiểm tra database $DB_NAME..."
db_count=$(run_sql "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '$DB_NAME'" | tr -d '[:space:]')
if [[ "$db_count" == "0" ]]; then
  echo "   Chưa có → đang restore từ /tmp/AdventureWorks2014.bak (khoảng 30 giây)..."
  # Ngay sau khi SQL Server vừa khởi động, RESTORE đôi khi lỗi tạm thời → thử lại tối đa 3 lần
  for attempt in 1 2 3; do
    if run_sql "RESTORE DATABASE [$DB_NAME] FROM DISK = '/tmp/AdventureWorks2014.bak'
           WITH MOVE 'AdventureWorks2014_Data' TO '/var/opt/mssql/data/AdventureWorks2014.mdf',
                MOVE 'AdventureWorks2014_Log' TO '/var/opt/mssql/data/AdventureWorks2014_log.ldf'"; then
      break
    fi
    if [[ "$attempt" -eq 3 ]]; then
      echo "   ❌ Restore thất bại sau 3 lần. Xem log: docker compose logs sqlserver"
      exit 1
    fi
    echo "   ⚠️  Restore lỗi (lần $attempt), thử lại sau 10 giây..."
    sleep 10
  done
  online=$(run_sql "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '$DB_NAME' AND state_desc = 'ONLINE'" | tr -d '[:space:]')
  if [[ "$online" != "1" ]]; then
    echo "   ❌ Đã chạy RESTORE nhưng database $DB_NAME chưa ở trạng thái ONLINE"
    exit 1
  fi
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
