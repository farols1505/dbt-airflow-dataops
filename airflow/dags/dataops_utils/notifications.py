"""Gửi thông báo Discord từ Airflow (callback khi task lỗi, thử lại, hoặc DAG chạy xong).

URL webhook lấy từ biến môi trường NOTIFY_WEBHOOK_URL (khai báo trong .env, truyền vào
container Airflow qua docker-compose.yml). Không có URL → chỉ ghi log, không gửi.

Lỗi khi gửi thông báo KHÔNG BAO GIỜ làm task/DAG thất bại.
"""

from __future__ import annotations

import json
import logging
import os
import urllib.request
from typing import Any

log = logging.getLogger(__name__)

WEBHOOK_ENV = "NOTIFY_WEBHOOK_URL"
GREEN = 0x2ECC71
YELLOW = 0xF1C40F
RED = 0xE74C3C


def send_discord(title: str, description: str, color: int, fields: list | None = None) -> bool:
    """Gửi một tin nhắn dạng embed tới Discord. Trả về True nếu gửi thành công."""
    url = os.environ.get(WEBHOOK_ENV, "").strip()
    if not url:
        log.info("Chưa cấu hình %s → bỏ qua gửi Discord: %s", WEBHOOK_ENV, title)
        return False

    payload = {
        "username": "Airflow DataOps",
        "embeds": [
            {
                "title": title[:256],
                "description": description[:4000],
                "color": color,
                "fields": fields or [],
            }
        ],
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "dataops-airflow/1.0"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            log.info("Đã gửi thông báo Discord (HTTP %s): %s", response.status, title)
        return True
    except Exception as exc:  # thông báo lỗi không được làm hỏng pipeline
        log.warning("Không gửi được thông báo Discord: %s", exc)
        return False


def _target(context: dict[str, Any]) -> str:
    """Môi trường dbt của lần chạy: params.target, hoặc biến AIRFLOW_VAR_DBT_TARGET."""
    params = context.get("params") or {}
    return params.get("target") or os.environ.get("AIRFLOW_VAR_DBT_TARGET", "dev")


def _field(name: str, value: Any, inline: bool = True) -> dict:
    return {"name": name, "value": str(value)[:1024], "inline": inline}


def notify_task_failure(context: dict[str, Any]) -> None:
    """Callback khi một task lỗi HẲN (đã hết số lần retry)."""
    ti = context["task_instance"]
    exception = context.get("exception")
    send_discord(
        title=f"❌ Airflow: task {ti.task_id} THẤT BẠI",
        description=f"DAG **{ti.dag_id}** · môi trường **{_target(context)}**",
        color=RED,
        fields=[
            _field("Run", context.get("run_id", "?"), inline=False),
            _field("Lỗi", exception or "xem log", inline=False),
            _field("Log", ti.log_url, inline=False),
        ],
    )


def notify_task_retry(context: dict[str, Any]) -> None:
    """Callback khi một task lỗi và sắp được chạy lại (retry)."""
    ti = context["task_instance"]
    send_discord(
        title=f"🔁 Airflow: task {ti.task_id} lỗi, đang thử lại",
        description=f"DAG **{ti.dag_id}** · môi trường **{_target(context)}**",
        color=YELLOW,
        fields=[
            _field("Lỗi", context.get("exception") or "xem log", inline=False),
            _field("Log", ti.log_url, inline=False),
        ],
    )


def notify_dag_success(context: dict[str, Any]) -> None:
    """Callback khi toàn bộ DAG chạy thành công."""
    dag_run = context.get("dag_run")
    duration = "?"
    if dag_run is not None and dag_run.start_date and dag_run.end_date:
        duration = f"{(dag_run.end_date - dag_run.start_date).total_seconds() / 60:.1f} phút"
    dag_id = getattr(dag_run, "dag_id", "?")
    send_discord(
        title="✅ Airflow: pipeline dbt chạy THÀNH CÔNG",
        description=f"DAG **{dag_id}** · môi trường **{_target(context)}**",
        color=GREEN,
        fields=[
            _field("Run", getattr(dag_run, "run_id", "?"), inline=False),
            _field("Thời gian chạy", duration),
        ],
    )
