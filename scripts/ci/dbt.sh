#!/usr/bin/env bash
# =============================================================================
# Chạy một lệnh dbt trong container dbt và LƯU LẠI kết quả với nhãn riêng.
#
#   ./scripts/ci/dbt.sh <nhãn> <tham số dbt...>
#   ví dụ: ./scripts/ci/dbt.sh build build
#          ./scripts/ci/dbt.sh run   run --full-refresh
#
# Vì sao cần? Mỗi lệnh dbt ghi đè dbt/target/run_results.json. Script này chép kết quả ra
# dbt/target/run_results_<nhãn>.json ngay sau lệnh, để bước tóm tắt (dbt_summary.py)
# hiển thị đủ kết quả của run, test, build... Mã thoát của dbt được giữ nguyên.
# =============================================================================
set -uo pipefail

LABEL="${1:?Cần truyền nhãn, vd. build}"
shift

cd "$(dirname "$0")/../.." || exit 1

# "| cat" + PIPESTATUS: output luôn đi qua pipe (Docker bản snap không ghi thẳng vào file được)
docker compose exec -T dbt dbt "$@" | cat
exit_code=${PIPESTATUS[0]}

docker compose exec -T dbt sh -c \
  "if [ -f target/run_results.json ]; then cp target/run_results.json target/run_results_${LABEL}.json; fi" \
  || true

exit "$exit_code"
