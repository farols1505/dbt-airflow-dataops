#!/usr/bin/env bash
# =============================================================================
# Đo hiệu năng của model incremental slvr_sales_orders (chạy trên máy local).
#
#   ./scripts/benchmark_incremental.sh            # target dev
#   ./scripts/benchmark_incremental.sh staging
#
# Đo 3 trường hợp:
#   1. Full refresh          : build lại toàn bộ ~121 nghìn dòng (giống bảng thường)
#   2. Incremental, không có dữ liệu mới : chỉ kiểm tra, gần như không xử lý dòng nào
#   3. Incremental, sau khi mô phỏng dữ liệu mới : chỉ xử lý các dòng vừa thay đổi
# In kết quả dạng bảng Markdown → dán vào docs/PERFORMANCE.md.
# =============================================================================
set -euo pipefail

TARGET="${1:-dev}"
cd "$(dirname "$0")/.."

# Thời gian thực thi (giây) của slvr_sales_orders trong lần chạy dbt gần nhất
last_execution_time() {
  docker compose exec -T dbt python -c "
import json
results = json.load(open('target/run_results.json'))['results']
print(round([r for r in results if r['unique_id'].endswith('.slvr_sales_orders')][0]['execution_time'], 2))
"
}

row_count() {
  docker compose exec -T dbt dbt run-operation health_check \
    --args "{layers: [silver]}" --target "$TARGET" 2>/dev/null \
    | grep -o "slvr_sales_orders: [0-9]* dòng" | grep -o "[0-9]*" || echo "?"
}

echo "⏳ 1/3 Full refresh..."
docker compose exec -T dbt dbt -q run --select slvr_sales_orders --full-refresh --target "$TARGET"
full=$(last_execution_time)

echo "⏳ 2/3 Incremental, không có dữ liệu mới..."
docker compose exec -T dbt dbt -q run --select slvr_sales_orders --target "$TARGET"
incr_none=$(last_execution_time)

echo "⏳ 3/3 Mô phỏng dữ liệu mới (20 đơn hàng) rồi chạy incremental..."
docker compose exec -T dbt dbt -q run-operation simulate_new_data --target "$TARGET"
docker compose exec -T dbt dbt -q run --select +slvr_sales_orders --target "$TARGET"
incr_new=$(last_execution_time)

rows=$(row_count)

cat <<EOF

### Kết quả đo — slvr_sales_orders (target: $TARGET, $(date '+%Y-%m-%d %H:%M'))

| Trường hợp | Thời gian (giây) |
|---|---|
| Full refresh ($rows dòng) | $full |
| Incremental — không có dữ liệu mới | $incr_none |
| Incremental — sau khi có dữ liệu mới (20 đơn hàng) | $incr_new |

EOF
