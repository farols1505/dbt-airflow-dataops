#!/usr/bin/env python3
"""Sinh sơ đồ lineage dạng Mermaid từ dbt manifest → docs/LINEAGE.md.

GitHub hiển thị Mermaid thành sơ đồ ngay trong trang Markdown, nên ai mở repo cũng thấy
luồng dữ liệu: nguồn → bronze → silver → gold → exposures (dashboard/báo cáo).

Cách dùng (chạy từ thư mục nào cũng được):
    docker compose exec dbt dbt parse          # tạo/cập nhật dbt/target/manifest.json
    python3 scripts/generate_lineage_mermaid.py

An toàn (SonarCloud S8707): không nhận đường dẫn từ dòng lệnh; file đọc/ghi là hằng số,
tính từ thư mục gốc của repo.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "dbt" / "target" / "manifest.json"
OUTPUT_PATH = REPO_ROOT / "docs" / "LINEAGE.md"

LAYER_STYLES = {
    "source": "fill:#eceff1,stroke:#607d8b,color:#263238",
    "bronze": "fill:#f3e0c7,stroke:#a0522d,color:#3e2723",
    "silver": "fill:#e0e0e0,stroke:#757575,color:#212121",
    "gold": "fill:#fff3c4,stroke:#c9a227,color:#3e2723",
    "exposure": "fill:#d7ecff,stroke:#1e6bb8,color:#0d2b45",
}


def node_id(unique_id: str) -> str:
    return unique_id.replace(".", "_").replace("-", "_")


def layer_of(node: dict) -> str:
    tags = node.get("tags", [])
    for layer in ("bronze", "silver", "gold"):
        if layer in tags or f"/{layer}/" in node.get("original_file_path", ""):
            return layer
    return "silver"


def build_mermaid(manifest: dict) -> str:
    lines = ["flowchart LR"]
    groups: dict[str, list[str]] = {k: [] for k in LAYER_STYLES}
    edges: list[str] = []

    for uid, src in manifest.get("sources", {}).items():
        groups["source"].append(f'    {node_id(uid)}["{src["source_name"]}.{src["name"]}"]')

    for uid, node in manifest.get("nodes", {}).items():
        if node.get("resource_type") != "model":
            continue
        groups[layer_of(node)].append(f'    {node_id(uid)}["{node["name"]}"]')
        for parent in node.get("depends_on", {}).get("nodes", []):
            edges.append(f"  {node_id(parent)} --> {node_id(uid)}")

    for uid, exposure in manifest.get("exposures", {}).items():
        label = exposure.get("label") or exposure["name"]
        groups["exposure"].append(f'    {node_id(uid)}(["{label}"])')
        for parent in exposure.get("depends_on", {}).get("nodes", []):
            edges.append(f"  {node_id(parent)} --> {node_id(uid)}")

    titles = {
        "source": "Nguồn (AdventureWorks)",
        "bronze": "Bronze",
        "silver": "Silver",
        "gold": "Gold",
        "exposure": "Nơi sử dụng",
    }
    for layer, members in groups.items():
        if not members:
            continue
        lines.append(f'  subgraph {layer}_layer["{titles[layer]}"]')
        lines += sorted(members)
        lines.append("  end")
        lines.append(f"  style {layer}_layer {LAYER_STYLES[layer]}")

    lines += sorted(set(edges))
    return "\n".join(lines)


def main() -> int:
    if not MANIFEST_PATH.exists():
        print(f"❌ Không tìm thấy {MANIFEST_PATH}. Chạy trước: docker compose exec dbt dbt parse")
        return 1
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    models = [n for n in manifest["nodes"].values() if n.get("resource_type") == "model"]
    content = "\n".join(
        [
            "# Lineage — luồng dữ liệu",
            "",
            "> File này được **sinh tự động** bởi `scripts/generate_lineage_mermaid.py` "
            "từ dbt manifest. Không sửa tay.",
            ">",
            "> Bản tương tác (bấm vào từng model, xem cột, SQL, test): trang tài liệu dbt trên "
            "GitHub Pages — https://farols1505.github.io/dbt-airflow-dataops/",
            "",
            f"**{len(manifest.get('sources', {}))} bảng nguồn · {len(models)} model · "
            f"{len(manifest.get('exposures', {}))} exposure**",
            "",
            "```mermaid",
            build_mermaid(manifest),
            "```",
            "",
        ]
    )
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(content, encoding="utf-8")
    print(f"✅ Đã ghi {OUTPUT_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
