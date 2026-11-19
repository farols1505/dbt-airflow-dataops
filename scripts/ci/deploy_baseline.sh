#!/usr/bin/env bash
# =============================================================================
# Dựng lại phiên bản PRODUCTION ĐANG CHẠY trong database tạm của GitHub Actions.
#
#   ./scripts/ci/deploy_baseline.sh <tag prod-*>
#
# Vì sao cần? Database trên GitHub Actions là tạm thời (tạo mới mỗi lần chạy). Để bước
# backup → deploy → (lỗi thì) restore có ý nghĩa thật, trước khi deploy phiên bản mới ta
# build lại phiên bản prod hiện tại (tag prod-* mới nhất) vào cùng database. Khi đó:
#   - backup chứa đúng dữ liệu của phiên bản đang chạy;
#   - nếu phiên bản mới lỗi, restore đưa prod về đúng trạng thái trước deploy.
#
# Cách làm: checkout tag cũ ra thư mục riêng (git worktree), chạy image dbt đã build
# với thư mục đó, kết nối tới cùng SQL Server và cùng target (đọc từ .env).
# =============================================================================
set -euo pipefail

TAG="${1:?Cần truyền tag phiên bản prod, vd. prod-20261113-1530}"

cd "$(dirname "$0")/../.."

# Tên image/network do docker compose đặt theo tên project: "name: dbt_airflow_project" trong
# docker-compose.yml, hoặc biến COMPOSE_PROJECT_NAME nếu được đặt (biến này được ưu tiên).
PROJECT="${COMPOSE_PROJECT_NAME:-dbt_airflow_project}"
DBT_IMAGE="${PROJECT}-dbt"
NETWORK="${PROJECT}_dbt_airflow_network"

WORKTREE="$(mktemp -d)/baseline"
git worktree add --detach "$WORKTREE" "$TAG"

echo "▶ Dựng phiên bản production hiện tại: $TAG ($(git rev-parse --short "$TAG"))"
docker run --rm \
  --network "$NETWORK" \
  --env-file .env \
  -e DBT_SERVER=sqlserver \
  -e DBT_PORT=1433 \
  -v "$WORKTREE/dbt:/usr/app/dbt" \
  "$DBT_IMAGE" \
  bash -c "dbt deps && dbt run" | cat   # pipefail giữ mã thoát của docker run

echo "✅ Đã dựng lại phiên bản $TAG — sẵn sàng backup"
