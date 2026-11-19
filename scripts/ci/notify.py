#!/usr/bin/env python3
"""Thông báo kết quả deploy: ghi vào GitHub Job Summary và gửi Discord (nếu có webhook).

Biến môi trường:
    NOTIFY_WEBHOOK_URL   URL webhook Discord (GitHub Secret). Bỏ trống → chỉ ghi Job Summary.
    GITHUB_*             Do GitHub Actions tự cung cấp (repo, run id, người kích hoạt...).

Cách dùng:
    python3 scripts/ci/notify.py --status success --environment production \
        --sha abc1234 --tag prod-20261113-1530 --rolled-back false

Không bao giờ làm job thất bại vì lỗi gửi thông báo (luôn trả mã 0).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request

COLORS = {"success": 0x2ECC71, "failure": 0xE74C3C, "cancelled": 0x95A5A6}
ICONS = {"success": "✅", "failure": "❌", "cancelled": "⏹️"}


def build_message(args: argparse.Namespace) -> tuple[str, str, list[dict]]:
    repo = os.environ.get("GITHUB_REPOSITORY", "local")
    actor = os.environ.get("GITHUB_ACTOR", "?")
    status = args.status
    rolled_back = args.rolled_back.lower() == "true"

    if args.is_rollback.lower() == "true":
        action = "Rollback thủ công"
    else:
        action = "Deploy"

    if status == "success":
        result = "thành công"
    elif rolled_back:
        result = "THẤT BẠI — đã tự động rollback về dữ liệu trước deploy"
    else:
        result = "THẤT BẠI"

    title = f"{ICONS.get(status, 'ℹ️')} {action} → {args.environment}: {result}"
    description = f"Repo **{repo}** · người kích hoạt: **{actor}**"
    fields = [
        {"name": "Môi trường", "value": args.environment, "inline": True},
        {"name": "Commit", "value": f"`{args.sha[:7]}`" if args.sha else "?", "inline": True},
    ]
    if args.tag:
        fields.append({"name": "Tag phiên bản", "value": f"`{args.tag}`", "inline": True})
    if args.reason:
        fields.append({"name": "Lý do", "value": args.reason[:1000], "inline": False})
    return title, description, fields


def run_url() -> str:
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    repo = os.environ.get("GITHUB_REPOSITORY")
    run_id = os.environ.get("GITHUB_RUN_ID")
    return f"{server}/{repo}/actions/runs/{run_id}" if repo and run_id else ""


def write_job_summary(title: str, description: str, fields: list[dict], url: str) -> None:
    lines = [f"## {title}", "", description, ""]
    lines += [f"- **{f['name']}:** {f['value']}" for f in fields]
    if url:
        lines += ["", f"[Xem chi tiết lần chạy]({url})"]
    text = "\n".join(lines) + "\n"
    print(text)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(text)


def send_discord(title: str, description: str, fields: list[dict], url: str, status: str) -> None:
    webhook = os.environ.get("NOTIFY_WEBHOOK_URL", "").strip()
    if not webhook:
        print("ℹ️  Chưa cấu hình secret NOTIFY_WEBHOOK_URL → bỏ qua gửi Discord.")
        return
    embed = {
        "title": title[:256],
        "description": description,
        "color": COLORS.get(status, 0x3498DB),
        "fields": fields,
    }
    if url:  # Discord từ chối "url": null → chỉ thêm khi có link
        embed["url"] = url
    payload = {"username": "DataOps CI/CD", "embeds": [embed]}
    request = urllib.request.Request(
        webhook,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "dataops-notifier/1.0"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            print(f"📣 Đã gửi thông báo Discord (HTTP {response.status}).")
    except Exception as exc:  # thông báo lỗi không được làm hỏng deploy
        print(f"::warning::Không gửi được thông báo Discord: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", required=True, help="success | failure | cancelled")
    parser.add_argument("--environment", required=True)
    parser.add_argument("--sha", default="")
    parser.add_argument("--tag", default="")
    parser.add_argument("--rolled-back", default="false")
    parser.add_argument("--is-rollback", default="false")
    parser.add_argument("--reason", default="")
    args = parser.parse_args()

    title, description, fields = build_message(args)
    url = run_url()
    write_job_summary(title, description, fields, url)
    send_discord(title, description, fields, url, args.status)
    return 0


if __name__ == "__main__":
    sys.exit(main())
