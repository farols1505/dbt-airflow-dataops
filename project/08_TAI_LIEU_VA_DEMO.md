# 08 — TÀI LIỆU VÀ DEMO

| | |
|---|---|
| **Phần chấm điểm** | Phần 5 — Documentation & Presentation (5đ) |
| **Thời gian** | 3–4 giờ (gồm 2 lần tập demo) |
| **Điều kiện** | Đã xong [`07`](07_ROLLBACK_VA_GIAM_SAT_DEPLOY.md) |
| **Kết quả** | Đủ tài liệu (kiến trúc + sơ đồ, setup guide, troubleshooting, kịch bản demo); repo gọn (tài liệu gốc của môn chuyển vào `docs/course/`); đã tập demo 2 lần. **Đạt mốc ~100 điểm** |

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Đọc lại và chỉnh tài liệu](#bước-1--đọc-lại-và-chỉnh-tài-liệu)
- [Bước 2 — Kiểm tra setup guide trên máy sạch](#bước-2--kiểm-tra-setup-guide-trên-máy-sạch)
- [Bước 3 — Commit và Pull Request](#bước-3--commit-và-pull-request)
- [Bước 4 — Phát hành lên main](#bước-4--phát-hành-lên-main)
- [Bước 5 — Tập demo](#bước-5--tập-demo)
- [Checklist nộp bài](#checklist-nộp-bài)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Trạng thái | Nội dung | Mục đích |
|---|---|---|---|
| `docs/ARCHITECTURE.md` | Mới | Thành phần, luồng dữ liệu (Mermaid), luồng Airflow, luồng CI/CD, **9 quyết định kỹ thuật** kèm lý do, bảo mật | "Architecture documentation", phần *Key technical decisions* khi thuyết trình |
| `docs/images/architecture.svg` | Mới | Sơ đồ kiến trúc 2 khối: GitHub (CI/CD) và máy local (Docker); hiển thị trong README | "Architecture diagram (PDF or image)" |
| `docs/SETUP_GUIDE.md` | Mới | Cài từ đầu trong ~30 phút: yêu cầu, clone, `.env`, khởi động, dbt, Airflow, Grafana/Discord tùy chọn | "Step-by-step setup guide for new developers" |
| `docs/TROUBLESHOOTING.md` | Mới | ~35 lỗi đã gặp, chia 4 nhóm: Docker, dbt, Airflow, Git/CI/CD | "Troubleshooting guide" |
| `docs/DEMO_SCRIPT.md` | Mới | Chuẩn bị, kịch bản 15 phút theo từng phút, phần "khó khăn & bài học", câu hỏi có thể gặp | Buổi demo trực tiếp |
| `docs/REQUIREMENTS_TRACEABILITY.md` | Mới | Từng yêu cầu của đề bài → file đáp ứng → cách kiểm chứng (chạy thật / kiểm tra tĩnh / trên GitHub) | Tự kiểm trước khi nộp; giáo viên đối chiếu nhanh |
| `docs/course/README.md` | Mới | Giải thích thư mục chứa tài liệu gốc của môn | Phân biệt tài liệu gốc với tài liệu dự án |
| 7 file tài liệu gốc ở thư mục gốc | Di chuyển | → `docs/course/` (giữ nguyên nội dung) | Repo gọn; tránh nhầm `1. README.md` với `README.md` |

> `README.md` đã commit ở file 03 và đã trỏ sẵn tới các file này. Sau bước này mọi link trong README đều hoạt động.

**Kế hoạch commit** (nhánh `docs/final-documentation`):

| # | Commit message |
|---|---|
| 1 | `docs: move course materials to docs/course` |
| 2 | `docs: add architecture overview and diagram` |
| 3 | `docs: add setup guide and troubleshooting` |
| 4 | `docs: add live demo script` |
| 5 | `docs: add requirements traceability matrix` |
| 6 | `docs: clarify that manual rollback can restore any tag` (bổ sung `docs/ROLLBACK.md` từ file 07) |

---

## Bước 1 — Đọc lại và chỉnh tài liệu

Tài liệu được viết sẵn theo hệ thống đã xây. Đọc lại và **chỉnh theo thực tế của bạn**:

| File | Cần kiểm tra |
|---|---|
| `README.md` | Mở bằng VS Code (Ctrl+Shift+V để xem trước): các link, bảng "Tính năng chính" đúng với những gì bạn đã làm; nếu bỏ bonus nào thì xóa dòng tương ứng |
| `docs/ARCHITECTURE.md` | Sơ đồ Mermaid hiển thị đúng (GitHub vẽ được Mermaid; VS Code cần extension *Markdown Preview Mermaid Support*) |
| `docs/images/architecture.svg` | Mở bằng trình duyệt; nếu muốn chỉnh, sửa trực tiếp file SVG (văn bản) hoặc vẽ lại bằng draw.io |
| `docs/TROUBLESHOOTING.md` | **Thêm các lỗi bạn đã gặp** trong quá trình làm (đề bài đánh giá cao phần này) |
| `docs/DEMO_SCRIPT.md` | Điều chỉnh thời lượng từng phần theo cách bạn trình bày |
| `docs/PERFORMANCE.md` | Đã điền số liệu thật ở file 04? |

---

## Bước 2 — Kiểm tra setup guide trên máy sạch

Đề bài: *"Detailed enough that a new developer could set up and run your project in under 30 minutes."*

**Cách tốt nhất:** nhờ một người bạn (hoặc dùng máy khác) làm theo `docs/SETUP_GUIDE.md`, bấm giờ, ghi lại chỗ vướng → sửa tài liệu.

**Nếu chỉ có một máy:** cài thử trong thư mục khác với **tên project khác** (biến `COMPOSE_PROJECT_NAME` được ưu tiên hơn `name:` trong file) → container, volume, network hoàn toàn mới, không đụng hệ thống chính:

```bash
# Dừng hệ thống chính (trùng cổng 1433, 8080)
cd ~/HCMUS/Advanced_DevOps/DataOps/dbt_airflow_project && docker compose stop

cd /tmp && git clone git@github.com:farols1505/dbt-airflow-dataops.git setup-test && cd setup-test
export COMPOSE_PROJECT_NAME=setuptest
# Làm theo docs/SETUP_GUIDE.md từ mục 3 tới mục 5, bấm giờ.
# (Mục 6 — DAG Airflow — không chạy được trong bản thử này vì DAG gọi container tên dbt_airflow_project-dbt-1.)

# Dọn bản thử: -v ở đây chỉ xóa volume của project "setuptest"
docker compose down -v
unset COMPOSE_PROJECT_NAME
cd ~ && rm -rf /tmp/setup-test

# Bật lại hệ thống chính
cd ~/HCMUS/Advanced_DevOps/DataOps/dbt_airflow_project && docker compose up -d
```

---

## Bước 3 — Commit và Pull Request

```bash
git switch develop && git pull
git switch -c docs/final-documentation

# 1. Chuyển tài liệu gốc của môn vào docs/course/
git mv "0. NEW_COMPUTER_SETUP.md" "1. README.md" "2. HANDS_ON_LAB_GUIDE.md" \
       "3. DATAOPS_LAB_GUIDE.md" "4. DATAOPS_PROJECT_REQUIREMENTS.md" \
       docker_commands.md TROUBLESHOOTING.md docs/course/
git add docs/course/README.md
git commit -m "docs: move course materials to docs/course"

# 2
git add docs/ARCHITECTURE.md docs/images/architecture.svg
git commit -m "docs: add architecture overview and diagram"

# 3
git add docs/SETUP_GUIDE.md docs/TROUBLESHOOTING.md
git commit -m "docs: add setup guide and troubleshooting"

# 4
git add docs/DEMO_SCRIPT.md
git commit -m "docs: add live demo script"

# 5
git add docs/REQUIREMENTS_TRACEABILITY.md
git commit -m "docs: add requirements traceability matrix"

# 6 — làm rõ: rollback thủ công không dùng backup, quay về được tag bất kỳ
git add docs/ROLLBACK.md project/08_TAI_LIEU_VA_DEMO.md   # + chính file hướng dẫn này (đã thêm commit 6)
git commit -m "docs: clarify that manual rollback can restore any tag"

git push -u origin docs/final-documentation
gh pr create --base develop --title "docs: complete project documentation" \
  --body "Kiến trúc + sơ đồ, setup guide, troubleshooting, kịch bản demo; chuyển tài liệu gốc vào docs/course."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --squash --delete-branch && git switch develop && git pull
```

> `git mv` giữ lịch sử của file. pre-commit có thể sửa khoảng trắng cuối dòng trong tài liệu gốc → `git add` lại rồi commit lại.

Kiểm tra trên GitHub: `gh repo view --web` → README hiển thị sơ đồ kiến trúc, mọi link mở được.

---

## Bước 4 — Phát hành lên main

```bash
gh pr create --base main --head develop --title "chore(release): complete documentation" \
  --body "Phát hành tài liệu hoàn chỉnh."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --merge
gh run watch            # duyệt production khi tới lượt
```

✅ **Mốc ~100 điểm:** mọi yêu cầu bắt buộc của 5 phần đã xong.

---

## Bước 5 — Tập demo

Làm theo [`docs/DEMO_SCRIPT.md`](../docs/DEMO_SCRIPT.md), **bấm giờ**, ít nhất 2 lần.

### 5.1. Chuẩn bị nhánh demo cho phần CI

```bash
git switch develop && git pull
git switch -c feature/demo-change
# Sửa nhỏ một mô tả, vd. trong dbt/models/gold/_gold__models.yml đổi mô tả của gld_sales_summary
git add dbt/models/gold/_gold__models.yml
git commit -m "docs(dbt): clarify sales summary description"
git push -u origin feature/demo-change
git switch develop
# KHÔNG mở PR — để mở trực tiếp lúc demo
```

### 5.2. Chuẩn bị tài liệu cho phần "khó khăn & bài học"

Mục *Khó khăn & bài học* trong `DEMO_SCRIPT.md` đã liệt kê 5 vấn đề thật của dự án (SQL Server trên CI, macro schema, docker.sock, dữ liệu tĩnh, database CI tạm thời). Với mỗi vấn đề, chuẩn bị 1 câu: **vấn đề → nguyên nhân → cách giải**.

### 5.3. Ảnh chụp dự phòng

Chụp lại và lưu (không cần commit): PR với 4 check xanh, Summary của `dbt-build`, lần chạy Deploy có *Review deployments*, Airflow Grid xanh, tin Discord (thành công, retry, rollback), Grafana, trang lineage.

---

## Checklist nộp bài

Đối chiếu mục *Submission Requirements* của đề bài:

**Code repository**
- [ ] Repo GitHub đầy đủ code; nhánh `main`, `develop`, các nhánh `feature/...` (xem `gh pr list --state merged`)
- [ ] Commit theo Conventional Commits (`git log --oneline develop | head -30`)
- [ ] README có hướng dẫn cài đặt

**Documentation**
- [ ] Sơ đồ kiến trúc (`docs/images/architecture.svg`)
- [ ] Setup guide (`docs/SETUP_GUIDE.md`)
- [ ] Tài liệu model (mô tả trong YAML + trang tài liệu dbt; file 10 đưa lên GitHub Pages)
- [ ] Troubleshooting guide (`docs/TROUBLESHOOTING.md`)

**Presentation**
- [ ] Demo trực tiếp 15 phút, đã tập ≥ 2 lần
- [ ] Nội dung: tổng quan, kiến trúc, quyết định kỹ thuật, khó khăn & cách giải, demo pipeline, bài học

**Liêm chính học thuật**
- [ ] README ghi rõ làm một mình + **khai báo sử dụng AI**
- [ ] Hiểu và giải thích được mọi file đã nộp

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| README không hiện sơ đồ | Sai đường dẫn ảnh, hoặc chưa merge file SVG | Đường dẫn đúng: `docs/images/architecture.svg`; kiểm tra file đã có trên nhánh đang xem |
| Sơ đồ Mermaid hiện thành code | Xem bằng công cụ không hỗ trợ Mermaid | Xem trên GitHub, hoặc cài extension Mermaid cho VS Code |
| `git mv` báo `No such file` | Tên file có dấu cách | Giữ nguyên dấu ngoặc kép như lệnh mẫu |
| Link tới `docs/course/4. DATAOPS_...` lỗi trên GitHub | Chưa merge bước di chuyển | Merge PR Bước 3 |
| Demo quá giờ | Phần chờ CI/deploy lâu | Dùng lần chạy có sẵn (mở link), chỉ kích hoạt mới phần ngắn (PR + check `validate-pr`, trigger DAG) |

---

## Tiếp theo

Mốc 100 điểm đã xong. Phần bonus:
→ **`09_GRAFANA_MONITORING.md`** (Bonus 1)
→ **`10_LINEAGE_GITHUB_PAGES.md`** (Bonus 2)
