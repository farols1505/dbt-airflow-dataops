#!/usr/bin/env python3
"""Báo cáo deployment: tỉ lệ thành công, thời gian chạy, lịch sử phiên bản production.

Nguồn dữ liệu:
    - Lịch sử chạy workflow deploy.yml và rollback.yml (qua GitHub CLI `gh run list`).
    - Các tag prod-* (mỗi tag = một lần deploy/rollback production thành công).

Cách dùng (cần đăng nhập gh, hoặc biến GH_TOKEN trên GitHub Actions):
    python3 scripts/ci/deploy_report.py --limit 100 --output deployment-report.md
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone

WORKFLOWS = {"deploy.yml": "Deploy", "rollback.yml": "Rollback (thủ công)"}
RUN_FIELDS = "databaseId,conclusion,status,headBranch,event,createdAt,updatedAt,url,displayTitle"


def gh_runs(workflow: str, limit: int) -> list[dict]:
    """Danh sách lần chạy đã KẾT THÚC của một workflow."""
    result = subprocess.run(
        ["gh", "run", "list", "--workflow", workflow, "--limit", str(limit), "--json", RUN_FIELDS],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(f"::warning::Không đọc được lịch sử {workflow}: {result.stderr.strip()}")
        return []
    return [r for r in json.loads(result.stdout or "[]") if r.get("status") == "completed"]


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def duration_minutes(run: dict) -> float:
    return (parse_time(run["updatedAt"]) - parse_time(run["createdAt"])).total_seconds() / 60


def prod_tags() -> list[tuple[str, str, str]]:
    """(tag, thời điểm, mô tả) của các tag prod-*, mới nhất trước."""
    result = subprocess.run(
        [
            "git",
            "tag",
            "-l",
            "prod-*",
            "--sort=-creatordate",
            "--format=%(refname:short)|%(creatordate:iso8601)|%(contents:subject)",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    tags = []
    for line in result.stdout.splitlines():
        parts = line.split("|", 2)
        if len(parts) == 3:
            tags.append((parts[0], parts[1], parts[2]))
    return tags


def environment_of(workflow: str, branch: str) -> str:
    if workflow == "rollback.yml":
        return "production (rollback)"
    return {"develop": "dev", "main": "staging → production"}.get(branch, branch)


def build_report(limit: int) -> str:
    stats: dict[tuple[str, str], dict] = defaultdict(lambda: {"total": 0, "success": 0, "mins": []})
    recent: list[tuple[str, dict]] = []

    for workflow in WORKFLOWS:
        for run in gh_runs(workflow, limit):
            key = (workflow, environment_of(workflow, run.get("headBranch", "?")))
            stats[key]["total"] += 1
            stats[key]["success"] += 1 if run.get("conclusion") == "success" else 0
            stats[key]["mins"].append(duration_minutes(run))
            recent.append((workflow, run))

    lines = [
        "# 📊 Báo cáo deployment",
        "",
        f"_Tạo lúc {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC — "
        f"thống kê tối đa {limit} lần chạy gần nhất mỗi workflow._",
        "",
        "## Tỉ lệ thành công",
        "",
        "| Workflow | Môi trường | Số lần | Thành công | Thất bại | Tỉ lệ thành công "
        "| Thời gian TB |",
        "|---|---|---|---|---|---|---|",
    ]
    if not stats:
        lines.append("| _(chưa có lần deploy nào)_ | | | | | | |")
    for (workflow, env), s in sorted(stats.items()):
        failed = s["total"] - s["success"]
        rate = 100 * s["success"] / s["total"] if s["total"] else 0
        avg = sum(s["mins"]) / len(s["mins"]) if s["mins"] else 0
        lines.append(
            f"| {WORKFLOWS[workflow]} | {env} | {s['total']} | {s['success']} | {failed} "
            f"| **{rate:.0f}%** | {avg:.1f} phút |"
        )

    lines += [
        "",
        "## 10 lần chạy gần nhất",
        "",
        "| Thời điểm | Workflow | Nhánh | Kết quả | Chi tiết |",
        "|---|---|---|---|---|",
    ]
    recent.sort(key=lambda item: item[1]["createdAt"], reverse=True)
    for workflow, run in recent[:10]:
        icon = "✅" if run.get("conclusion") == "success" else "❌"
        lines.append(
            f"| {run['createdAt'][:16].replace('T', ' ')} | {WORKFLOWS[workflow]} "
            f"| `{run.get('headBranch', '?')}` | {icon} {run.get('conclusion')} "
            f"| [xem]({run.get('url')}) |"
        )

    lines += [
        "",
        "## Lịch sử phiên bản production (tag prod-*)",
        "",
        "| Tag | Thời điểm | Mô tả |",
        "|---|---|---|",
    ]
    tags = prod_tags()
    if not tags:
        lines.append("| _(chưa có)_ | | |")
    for tag, when, subject in tags[:20]:
        lines.append(f"| `{tag}` | {when[:16]} | {subject} |")

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--output", default="deployment-report.md")
    args = parser.parse_args()

    report = build_report(args.limit)
    print(report)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(report)

    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
