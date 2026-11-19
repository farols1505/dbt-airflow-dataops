#!/usr/bin/env python3
"""Tóm tắt kết quả dbt cho GitHub Actions.

Đọc các file dbt/target/run_results_<nhãn>.json (do scripts/ci/dbt.sh tạo ra), in bảng tóm tắt
ra log và ghi vào GitHub Job Summary (trang tóm tắt của mỗi lần chạy workflow).

Cách dùng:
    python3 scripts/ci/dbt_summary.py "Tiêu đề"
"""

from __future__ import annotations

import glob
import json
import os
import sys
from collections import Counter
from pathlib import Path

RESULTS_GLOB = "dbt/target/run_results_*.json"
OK_STATUSES = {"success", "pass"}
FAIL_STATUSES = {"error", "fail", "runtime error"}


def summarize(path: str) -> tuple[str, list[str]]:
    """Trả về (một dòng bảng tóm tắt, danh sách dòng chi tiết lỗi/cảnh báo)."""
    label = Path(path).stem.replace("run_results_", "")
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    results = data.get("results", [])
    counts = Counter(r.get("status", "unknown") for r in results)

    ok = sum(counts[s] for s in OK_STATUSES)
    failed = sum(counts[s] for s in FAIL_STATUSES)
    warned = counts["warn"]
    skipped = counts["skipped"]
    elapsed = data.get("elapsed_time", 0.0)
    if failed:
        icon = "❌"
    elif warned:
        icon = "⚠️"
    else:
        icon = "✅"

    row = (
        f"| {icon} `{label}` | {ok} | {warned} | {failed} | {skipped} "
        f"| {len(results)} | {elapsed:.1f}s |"
    )

    details = []
    for r in results:
        status = r.get("status")
        if status in FAIL_STATUSES or status == "warn":
            node = r.get("unique_id", "?").split(".")[-1]
            message = (r.get("message") or "").strip().splitlines()
            first_line = message[0] if message else ""
            details.append(f"- **{status}** `{node}`: {first_line}")
    return row, details


def main() -> int:
    title = sys.argv[1] if len(sys.argv) > 1 else "Kết quả dbt"
    files = sorted(glob.glob(RESULTS_GLOB), key=os.path.getmtime)

    lines = [f"### {title}", ""]
    if not files:
        lines.append("_Không có kết quả dbt (lệnh dbt chưa chạy hoặc lỗi trước khi chạy)._")
    else:
        lines += [
            "| Bước | Thành công | Cảnh báo | Lỗi | Bỏ qua | Tổng | Thời gian |",
            "|---|---|---|---|---|---|---|",
        ]
        all_details: list[str] = []
        for path in files:
            row, details = summarize(path)
            lines.append(row)
            all_details += details
        if all_details:
            lines += ["", "**Chi tiết lỗi / cảnh báo:**", ""] + all_details[:50]

    report = "\n".join(lines) + "\n"
    print(report)

    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
