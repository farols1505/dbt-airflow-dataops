#!/usr/bin/env bash
# =============================================================================
# Tạo file .env cho môi trường TẠM trên GitHub Actions.
#
#   ./scripts/ci/create_env.sh <target>        target: ci | dev | staging | prod
#
# - Mật khẩu SA và dbt: lấy từ biến môi trường SECRET_SA_PASSWORD / SECRET_DBT_PASSWORD
#   (workflow gán từ GitHub Secrets SA_PASSWORD / DBT_ENV_SECRET_PASSWORD của từng Environment)
#   nếu có giá trị; không có thì sinh ngẫu nhiên.
#   Cố ý KHÔNG nhận qua tên SA_PASSWORD / DBT_ENV_SECRET_PASSWORD: docker compose ưu tiên biến
#   môi trường hơn file .env, và secret chưa tạo = chuỗi RỖNG → sẽ ghi đè mật khẩu trong .env.
# - Mọi giá trị bí mật được che (mask) trong log GitHub Actions.
# - Database tạm bị xóa khi job kết thúc, nên mật khẩu chỉ dùng một lần.
# =============================================================================
set -euo pipefail

TARGET="${1:?Cần truyền target: ci | dev | staging | prod}"
case "$TARGET" in
  ci | dev | staging | prod) ;;
  *) echo "❌ Target không hợp lệ: $TARGET" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/../.."

# Mật khẩu ngẫu nhiên: chữ hoa + chữ thường + số (đạt chính sách mật khẩu của SQL Server)
gen_password() { echo "Gh$(openssl rand -hex 12)X9"; }

SA_PASSWORD="${SECRET_SA_PASSWORD:-$(gen_password)}"
DBT_PASSWORD="${SECRET_DBT_PASSWORD:-$(gen_password)}"
POSTGRES_PASSWORD="$(gen_password)"
AIRFLOW_ADMIN_PASSWORD="$(gen_password)"
FERNET_KEY="$(python3 -c 'import base64, os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())')"

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  for secret in "$SA_PASSWORD" "$DBT_PASSWORD" "$POSTGRES_PASSWORD" "$AIRFLOW_ADMIN_PASSWORD" "$FERNET_KEY"; do
    echo "::add-mask::$secret"
  done
fi

cat > .env <<EOF
SA_PASSWORD=$SA_PASSWORD
DBT_USER=dbt_user
DBT_ENV_SECRET_PASSWORD=$DBT_PASSWORD
DBT_DATABASE=AdventureWorks2014
DBT_TARGET=$TARGET
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
AIRFLOW_FERNET_KEY=$FERNET_KEY
AIRFLOW_ADMIN_PASSWORD=$AIRFLOW_ADMIN_PASSWORD
DOCKER_GID=0
NOTIFY_WEBHOOK_URL=
EOF
chmod 600 .env

echo "✅ Đã tạo .env tạm cho target=$TARGET"
