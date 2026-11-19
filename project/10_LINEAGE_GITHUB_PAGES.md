# 10 — LINEAGE TRÊN GITHUB PAGES (Bonus 2)

| | |
|---|---|
| **Phần chấm điểm** | Bonus 2 — Data Lineage Visualization (+5đ) |
| **Thời gian** | 1–2 giờ |
| **Điều kiện** | Đã xong [`08`](08_TAI_LIEU_VA_DEMO.md) |
| **Kết quả** | Trang tài liệu dbt + **lineage tương tác** công khai tại https://farols1505.github.io/dbt-airflow-dataops/, tự cập nhật mỗi lần merge vào `main`; sơ đồ lineage Mermaid ngay trong repo; exposures nối lineage tới dashboard/báo cáo |

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Exposures: lineage tới tận nơi dùng dữ liệu](#bước-1--exposures-lineage-tới-tận-nơi-dùng-dữ-liệu)
- [Bước 2 — Sơ đồ lineage Mermaid trong repo](#bước-2--sơ-đồ-lineage-mermaid-trong-repo)
- [Bước 3 — Workflow đăng tài liệu lên GitHub Pages](#bước-3--workflow-đăng-tài-liệu-lên-github-pages)
- [Bước 4 — Bật GitHub Pages](#bước-4--bật-github-pages)
- [Bước 5 — Commit, Pull Request, phát hành](#bước-5--commit-pull-request-phát-hành)
- [Bước 6 — Xem và trình bày lineage](#bước-6--xem-và-trình-bày-lineage)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Nội dung | Mục đích |
|---|---|---|
| `dbt/models/exposures.yml` | 3 exposure: dashboard Grafana (`gld_sales_summary`, `gld_customer_segments`), phân tích RFM, báo cáo hiệu quả sản phẩm | Lineage đi tới **nơi dùng** dữ liệu; biết sửa model nào ảnh hưởng dashboard nào |
| `scripts/generate_lineage_mermaid.py` | Đọc `dbt/target/manifest.json` → sơ đồ Mermaid nhóm theo tầng (nguồn → bronze → silver → gold → nơi dùng), tô màu từng tầng | Xem lineage ngay trên GitHub, không cần mở trang khác |
| `docs/LINEAGE.md` | Sơ đồ do script sinh ra (7 nguồn, 14 model, 3 exposure, 25 cạnh) + link trang tương tác | |
| `.github/workflows/docs-pages.yml` | Khi merge vào `main`: dựng SQL Server tạm → `dbt run` (target prod) → `dbt docs generate --static` → đăng lên GitHub Pages | Trang lineage **tự động cập nhật** |

**Kế hoạch commit** (nhánh `feature/lineage-pages`):

| # | Commit message |
|---|---|
| 1 | `feat(dbt): add exposures for dashboards and reports` |
| 2 | `docs: add lineage diagram generator and generated diagram` |
| 3 | `ci: publish dbt docs and lineage to GitHub Pages` |

---

## Bước 1 — Exposures: lineage tới tận nơi dùng dữ liệu

```yaml
exposures:
  - name: grafana_dataops_dashboard
    label: "Grafana — DataOps Pipeline"
    type: dashboard
    url: http://localhost:3000/d/dataops-pipeline
    depends_on:
      - ref('gld_sales_summary')
      - ref('gld_customer_segments')
    owner:
      name: farols1505
```

Lợi ích: trên sơ đồ lineage, các exposure là **điểm cuối**. Chọn một model rồi xem các node phía sau nó → biết ngay dashboard/báo cáo nào bị ảnh hưởng nếu sửa model.

Kiểm tra:

```bash
docker compose exec dbt dbt ls --resource-type exposure
# exposure:dbt_sqlserver_project.customer_segmentation_analysis
# exposure:dbt_sqlserver_project.grafana_dataops_dashboard
# exposure:dbt_sqlserver_project.product_sales_report
docker compose exec dbt dbt ls --select +exposure:grafana_dataops_dashboard   # mọi node mà dashboard phụ thuộc
```

---

## Bước 2 — Sơ đồ lineage Mermaid trong repo

`docs/LINEAGE.md` đã được sinh sẵn. Sinh lại mỗi khi thêm/sửa model:

```bash
docker compose exec dbt dbt parse                    # cập nhật dbt/target/manifest.json
python3 scripts/generate_lineage_mermaid.py          # ✅ Đã ghi docs/LINEAGE.md
git diff --stat docs/LINEAGE.md
```

Xem trước: mở `docs/LINEAGE.md` trên GitHub (hoặc VS Code + extension Mermaid). Màu theo tầng: xám = nguồn, nâu = bronze, bạc = silver, vàng = gold, xanh dương = nơi dùng.

---

## Bước 3 — Workflow đăng tài liệu lên GitHub Pages

`.github/workflows/docs-pages.yml`:

| Job | Bước | Ghi chú |
|---|---|---|
| `build` | Dựng SQL Server + dbt (composite action, target `prod`) → `dbt run` → `dbt docs generate --static` → chép `static_index.html` thành `_site/index.html` → `upload-pages-artifact` | `dbt run` để trang có đủ kiểu dữ liệu và số dòng của bảng; `--static` gộp tài liệu thành **một file HTML** |
| `deploy` | `deploy-pages` → environment `github-pages` | URL trang hiện ở Summary |

Quyền `pages: write`, `id-token: write` (bắt buộc với GitHub Pages qua Actions); `concurrency: github-pages` để không đăng chồng.

---

## Bước 4 — Bật GitHub Pages

```bash
# Bật Pages với nguồn là GitHub Actions
gh api -X POST "repos/{owner}/{repo}/pages" -f build_type=workflow
gh api "repos/{owner}/{repo}/pages" --jq '{url: .html_url, build_type}'
```

GitHub tạo environment `github-pages` mà **mặc định chỉ cho nhánh mặc định** (`develop`) deploy. Workflow của ta chạy trên `main`, nên phải cho phép `main`:

```bash
gh api -X PUT "repos/{owner}/{repo}/environments/github-pages" --input - <<'EOF'
{ "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
EOF
gh api -X POST "repos/{owner}/{repo}/environments/github-pages/deployment-branch-policies" -f name=main -f type=branch
gh api "repos/{owner}/{repo}/environments/github-pages/deployment-branch-policies" --jq '.branch_policies[].name'
# main   (có thể thêm develop nếu GitHub đã tạo sẵn)
```

---

## Bước 5 — Commit, Pull Request, phát hành

```bash
git switch develop && git pull
git switch -c feature/lineage-pages

git add dbt/models/exposures.yml
git commit -m "feat(dbt): add exposures for dashboards and reports"

git add scripts/generate_lineage_mermaid.py docs/LINEAGE.md
git commit -m "docs: add lineage diagram generator and generated diagram"

git add .github/workflows/docs-pages.yml
git commit -m "ci: publish dbt docs and lineage to GitHub Pages"

git push -u origin feature/lineage-pages
gh pr create --base develop --title "feat: publish interactive data lineage to GitHub Pages" \
  --body "Exposures, sơ đồ lineage Mermaid, workflow đăng tài liệu dbt + lineage lên GitHub Pages."
gh pr checks --watch
gh pr merge --squash --delete-branch
git switch develop && git pull

# Phát hành lên main → kích hoạt docs-pages.yml (và Deploy staging → production)
gh pr create --base main --head develop --title "chore(release): data lineage on GitHub Pages" \
  --body "Phát hành exposures và trang lineage."
gh pr checks --watch
gh pr merge --merge
gh run list --workflow docs-pages.yml --limit 1
gh run watch
```

Nhớ duyệt production cho workflow **Deploy** chạy song song.

---

## Bước 6 — Xem và trình bày lineage

1. Mở **https://farols1505.github.io/dbt-airflow-dataops/** (hoặc link trong Summary của job `deploy`).
2. Trang chủ là nội dung `__overview__` (file `dbt/models/docs.md`).
3. Bấm biểu tượng **lineage** (góc dưới bên phải) → sơ đồ toàn dự án.
4. Gợi ý trình bày:
   - Chọn `gld_customer_segments` → `--select +gld_customer_segments` (gõ vào ô *select* dưới sơ đồ): thấy toàn bộ chuỗi phụ thuộc ngược về 7 bảng nguồn.
   - Chọn `slvr_sales_orders` → `slvr_sales_orders+`: thấy mọi bảng gold và exposure bị ảnh hưởng nếu sửa model này (*impact analysis*).
   - Bấm vào một model: mô tả, cột, SQL đã biên dịch, test.

Badge **Docs & Lineage** trong README chuyển xanh và dẫn tới trang này.

---

## Checklist hoàn thành

- [ ] `dbt ls --resource-type exposure` liệt kê 3 exposure
- [ ] `docs/LINEAGE.md` hiển thị sơ đồ trên GitHub
- [ ] GitHub Pages bật, environment `github-pages` cho phép `main`
- [ ] Workflow *Docs & Lineage* xanh; trang mở được, sơ đồ lineage có exposures
- [ ] Badge Docs & Lineage trong README xanh

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `gh api ... /pages` báo `409` | Pages đã bật | Bỏ qua; kiểm tra `build_type` là `workflow`: `gh api -X PUT repos/{owner}/{repo}/pages -f build_type=workflow` |
| Job `deploy` lỗi `Branch "main" is not allowed to deploy to github-pages` | Luật mặc định của environment | Làm phần thứ hai của Bước 4 rồi *Re-run failed jobs* |
| Job `deploy` lỗi `Get Pages site failed` | Pages chưa bật | Phần đầu Bước 4 |
| Trang trắng / không tải được | Dùng `index.html` thường (cần thêm file JSON) thay vì `static_index.html` | Workflow đã dùng `--static`; kiểm tra bước *Chuẩn bị nội dung trang* |
| Lineage không có exposures | `exposures.yml` chưa lên `main` | Phát hành lại |
| `generate_lineage_mermaid.py` báo không tìm thấy manifest | Chưa `dbt parse` | `docker compose exec dbt dbt parse` |
| Sơ đồ Mermaid không hiện trên GitHub | Lỗi cú pháp sau khi sửa tay | Không sửa tay `docs/LINEAGE.md`; chạy lại script |

---

## Hoàn thành dự án 🎉

Mọi phần bắt buộc + 3 bonus đã xong. Trước buổi demo: xem lại [`docs/DEMO_SCRIPT.md`](../docs/DEMO_SCRIPT.md) và checklist nộp bài ở [`08_TAI_LIEU_VA_DEMO.md`](08_TAI_LIEU_VA_DEMO.md#checklist-nộp-bài).
