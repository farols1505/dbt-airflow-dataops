# 07 — ROLLBACK VÀ GIÁM SÁT DEPLOYMENT

| | |
|---|---|
| **Phần chấm điểm** | Phần 4B "Rollback capability" + Phần 4C — Documentation & Monitoring (5đ) |
| **Thời gian** | 2–3 giờ (phần lớn là chờ deploy + duyệt) |
| **Điều kiện** | Đã xong [`06`](06_CD_VA_MULTI_ENV.md) (production có người duyệt, đã có ≥ 2 tag `prod-*`) |
| **Kết quả** | Đã **diễn tập** rollback tự động và rollback thủ công; báo cáo tỉ lệ deploy thành công; runbook + quy trình rollback |

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Rollback tự động hoạt động thế nào](#bước-1--rollback-tự-động-hoạt-động-thế-nào)
- [Bước 2 — Rollback thủ công](#bước-2--rollback-thủ-công)
- [Bước 3 — Báo cáo deployment](#bước-3--báo-cáo-deployment)
- [Bước 4 — Runbook và quy trình rollback](#bước-4--runbook-và-quy-trình-rollback)
- [Bước 5 — Commit, Pull Request, phát hành](#bước-5--commit-pull-request-phát-hành)
- [Bước 6 — Diễn tập rollback tự động](#bước-6--diễn-tập-rollback-tự-động)
- [Bước 7 — Diễn tập rollback thủ công](#bước-7--diễn-tập-rollback-thủ-công)
- [Bước 8 — Đưa production về phiên bản mới nhất](#bước-8--đưa-production-về-phiên-bản-mới-nhất)
- [Bước 9 — Chạy báo cáo deployment](#bước-9--chạy-báo-cáo-deployment)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Trạng thái | Nội dung | Mục đích |
|---|---|---|---|
| `.github/workflows/rollback.yml` | Mới | Chạy tay với `tag` + `reason`; job `validate` kiểm tra tag; job `rollback` gọi `_deploy.yml` deploy lại code của tag đó (vẫn cần duyệt), gắn tag `prod-...-rollback` | **Rollback thủ công** |
| `.github/workflows/deploy-report.yml` | Mới | Chạy 8:00 sáng thứ Hai (giờ VN) hoặc chạy tay; gọi `deploy_report.py`; lưu `deployment-report.md` (artifact 90 ngày) | "Monitor deployment success rates" |
| `scripts/ci/deploy_report.py` | Mới | Đọc lịch sử chạy `deploy.yml`, `rollback.yml` qua `gh run list` + các tag `prod-*` → bảng tỉ lệ thành công theo môi trường, thời gian TB, 10 lần gần nhất, lịch sử phiên bản | "Track deployment history" |
| `docs/DEPLOYMENT_RUNBOOK.md` | Mới | Quy trình deploy dev / phát hành production, checklist trước khi duyệt, các bước bên trong một lần deploy, xử lý sự cố, giám sát | "Create deployment runbook", "Document deployment process" |
| `docs/ROLLBACK.md` | Mới | So sánh 2 cơ chế, các bước rollback thủ công, diễn tập, giới hạn | "Document rollback procedures" |
| `dbt/macros/ops/backup_layers.sql`, `restore_layers.sql`, `scripts/ci/deploy_baseline.sh`, phần rollback trong `_deploy.yml` | Đã commit ở file 03 | Cơ chế rollback tự động | Bước này giải thích kỹ và diễn tập |

**Kế hoạch commit** (nhánh `ci/rollback-and-reporting`):

| # | Commit message |
|---|---|
| 1 | `ci: add manual rollback workflow` |
| 2 | `ci: add weekly deployment report` |
| 3 | `docs: add deployment runbook and rollback procedure` |

---

## Bước 1 — Rollback tự động hoạt động thế nào

Trong `_deploy.yml`, chỉ với **production**:

```
2. Dựng lại phiên bản prod đang chạy ─► 3. Backup ─► 4. dbt run ─► 5. dbt test ─► 6. health check ─► 7. tag
   (tag prod-* mới nhất)                 (silver,gold                │            │            │
                                          → *__backup)               └────────────┴────────────┴─ lỗi ─► ↩️ restore_layers
                                                                                                         + health check
```

| Thành phần | Vai trò |
|---|---|
| `scripts/ci/deploy_baseline.sh <tag>` | Database trên GitHub Actions là **tạm thời** (rỗng mỗi lần chạy). Script checkout tag cũ ra thư mục riêng (`git worktree`) và chạy `dbt run` của phiên bản đó bằng image dbt đã build → database có đúng dữ liệu của phiên bản production đang chạy |
| `backup_layers` | Chép mọi bảng `prod_silver`, `prod_gold` → `prod_silver__backup`, `prod_gold__backup` |
| `restore_layers` | Xóa bảng hiện tại, chép lại từ backup; xóa bảng mới không có trong backup |
| Điều kiện rollback | `if: failure() && steps.backup.outcome == 'success'` → chỉ chạy khi có lỗi **và** đã backup thành công |
| Sau rollback | Job vẫn **đỏ** (để biết có lỗi) nhưng Summary + Discord ghi *"đã tự động rollback"*; **không** gắn tag mới |

> Với một production thật (database lâu dài), bỏ bước 2 vì dữ liệu đang có sẵn; các bước còn lại giữ nguyên.

---

## Bước 2 — Rollback thủ công

Dùng khi deploy đã **thành công** nhưng sau đó mới phát hiện lỗi (vd. số liệu sai mà test không bắt được).

```bash
gh workflow run rollback.yml --ref main -f tag=prod-20261114-0930 -f reason="Doanh thu gold sai"
```

| Job | Làm gì |
|---|---|
| `validate` | Tag đúng dạng `prod-YYYYMMDD-HHMM(-rollback)` và tồn tại; ghi yêu cầu vào Summary |
| `rollback` | Gọi `_deploy.yml` với `ref = tag`, `is_rollback = true`: chờ duyệt → dựng bản prod hiện tại → backup → deploy code **của tag cũ** → test → health check → gắn tag `prod-<giờ hiện tại>-rollback` trỏ về commit cũ → thông báo |

Tag mới nhất luôn là **phiên bản production hiện hành**, nên lần deploy sau tự coi phiên bản sau rollback là "bản đang chạy".

> Input `tag` và `reason` được truyền qua biến môi trường và kiểm tra bằng biểu thức chính quy trước khi dùng → không bị chèn lệnh.

---

## Bước 3 — Báo cáo deployment

`scripts/ci/deploy_report.py` tạo báo cáo Markdown gồm:

| Phần | Nguồn |
|---|---|
| Tỉ lệ thành công theo workflow + môi trường, thời gian trung bình | `gh run list --workflow deploy.yml / rollback.yml` (chỉ các lần đã kết thúc) |
| 10 lần chạy gần nhất (kèm link) | như trên |
| Lịch sử phiên bản production | `git tag -l 'prod-*' --sort=-creatordate` |

Chạy được cả trên máy (cần `gh auth login`):

```bash
python3 scripts/ci/deploy_report.py --limit 50          # chỉ in ra màn hình
```

- `--limit` nhận 1–200 (số lần chạy gần nhất mỗi workflow). `--save` ghi thêm file `deployment-report.md` (workflow dùng cờ này để tạo artifact); trên máy không cần.
- Khi `rollback.yml` chưa có trên `develop`, script in cảnh báo `HTTP 404 ... rollback.yml` và bỏ qua phần rollback — bình thường cho tới khi PR được merge.
- **Vì sao không có `--output <đường dẫn>`?** SonarCloud coi giá trị dòng lệnh đưa thẳng vào lệnh `gh` (rule S8705) hoặc vào đường dẫn file (S8707) là lỗ hổng bảo mật → Quality Gate đỏ. Script luôn gọi `gh` với số cố định (200) rồi cắt danh sách trong Python, và chỉ ghi vào tên file cố định.

---

## Bước 4 — Runbook và quy trình rollback

- [`docs/DEPLOYMENT_RUNBOOK.md`](../docs/DEPLOYMENT_RUNBOOK.md): ai làm gì, theo thứ tự nào; **checklist trước khi duyệt production**; bảng "bước nào lỗi thì sao"; xử lý sự cố; nơi xem các chỉ số deployment.
- [`docs/ROLLBACK.md`](../docs/ROLLBACK.md): khi nào dùng rollback tự động/thủ công, từng bước rollback thủ công, việc cần làm sau rollback, giới hạn của cơ chế.

Đọc lướt cả hai trước khi diễn tập ở Bước 6–7 (diễn tập chính là làm theo runbook).

---

## Bước 5 — Commit, Pull Request, phát hành

Workflow chạy tay (`workflow_dispatch`) chỉ dùng được khi file workflow đã có trên nhánh được chọn → phải phát hành lên `main`.

```bash
git switch develop && git pull
git switch -c ci/rollback-and-reporting

git add .github/workflows/rollback.yml
git commit -m "ci: add manual rollback workflow"

git add .github/workflows/deploy-report.yml scripts/ci/deploy_report.py
git commit -m "ci: add weekly deployment report"

git add docs/DEPLOYMENT_RUNBOOK.md docs/ROLLBACK.md
git commit -m "docs: add deployment runbook and rollback procedure"

git push -u origin ci/rollback-and-reporting
gh pr create --base develop --title "ci: add rollback workflow, deployment report and runbook" \
  --body "Rollback thủ công theo tag, báo cáo tỉ lệ deploy thành công hằng tuần, runbook và quy trình rollback."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --squash --delete-branch && git switch develop && git pull

# Phát hành lên main
gh pr create --base main --head develop --title "chore(release): rollback and deployment reporting" \
  --body "Phát hành workflow rollback, báo cáo deployment, runbook."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --merge
```

Duyệt production như file 06 (Bước 5.3) → tag `prod-*` thứ 3.

```bash
git fetch --tags && git tag -l 'prod-*' --sort=-creatordate
```

---

## Bước 6 — Diễn tập rollback tự động

Không cần làm hỏng code: `deploy.yml` có input `simulate_failure` → cố ý báo lỗi **ngay sau** `dbt run` (sau khi đã backup).

```bash
gh workflow run deploy.yml --ref main -f simulate_failure=true
gh run watch          # staging chạy bình thường (staging không nhận simulate_failure)
```

Duyệt production → quan sát job production:

| Bước | Kết quả mong đợi |
|---|---|
| 2. Dựng lại phiên bản đang chạy | ✅ |
| 3. Backup | ✅ |
| 4. dbt run | ✅ |
| Diễn tập: cố ý gây lỗi | ❌ `Lỗi giả lập để diễn tập rollback tự động` |
| 5, 6, 7 | *skipped* |
| ↩️ Rollback tự động | ✅ log `♻️ prod_gold__backup.X → prod_gold.X` + health check OK |
| 8b. Thông báo | Discord ❌ *"THẤT BẠI — đã tự động rollback về dữ liệu trước deploy"* |

Kết quả: job đỏ, **không có tag mới** (production vẫn là phiên bản cũ). Chụp màn hình Summary và tin Discord cho buổi demo.

---

## Bước 7 — Diễn tập rollback thủ công

> **Điều kiện:** đã xong **toàn bộ Bước 5**: PR đã merge vào `develop` **và** đã phát hành lên `main` (duyệt production). `gh workflow run` tìm workflow trên nhánh mặc định (`develop`) rồi chạy bản trên `--ref main`; thiếu ở một trong hai nơi → `HTTP 404: Not Found (.../workflows/rollback.yml)`.
> Kiểm tra nhanh: `gh workflow list` phải có dòng **Rollback (thủ công)**.

```bash
git fetch --tags
git tag -l 'prod-*' --sort=-creatordate --format='%(refname:short)  %(contents:subject)'
```

Chọn tag **thứ hai** (phiên bản ngay trước bản hiện tại), vd. `prod-20261114-0930`:

```bash
gh workflow run rollback.yml --ref main -f tag=prod-20261114-0930 -f reason="Diễn tập rollback thủ công"
gh run watch
```

Duyệt production → kết quả:
- Job `validate` ✅, Summary ghi tag + lý do + người yêu cầu.
- Job `rollback` ✅ → tag mới `prod-<giờ>-rollback` trỏ về commit của tag cũ.
- Discord ✅ *"Rollback thủ công → production: thành công"*.

```bash
git fetch --tags
git tag -l 'prod-*' --sort=-creatordate | head -3
git rev-parse --short "$(git tag -l 'prod-*' --sort=-creatordate | head -1)^{commit}"   # = commit của tag cũ
```

---

## Bước 8 — Đưa production về phiên bản mới nhất

Sau diễn tập, production đang chạy bản cũ. Deploy lại bản mới nhất của `main`:

```bash
gh workflow run deploy.yml --ref main
gh run watch     # duyệt production khi tới lượt
git fetch --tags && git tag -l 'prod-*' --sort=-creatordate | head -1    # tag mới trỏ về HEAD của main
```

---

## Bước 9 — Chạy báo cáo deployment

```bash
gh workflow run deploy-report.yml
gh run watch
```

Mở lần chạy → **Summary**: bảng tỉ lệ thành công (Deploy dev; staging → production; Rollback), 10 lần gần nhất, lịch sử tag. Lần diễn tập ở Bước 6 được tính là **thất bại** (đúng thực tế). Tải artifact `deployment-report.md` nếu cần đưa vào báo cáo.

---

## Checklist hoàn thành

- [ ] PR đã merge, đã phát hành lên `main` (tag thứ 3)
- [ ] Diễn tập rollback tự động: job đỏ, bước rollback xanh, Discord báo "đã rollback", không có tag mới
- [ ] Diễn tập rollback thủ công: tag `prod-...-rollback` trỏ về commit cũ
- [ ] Đã deploy lại bản mới nhất (Bước 8)
- [ ] Báo cáo deployment hiển thị tỉ lệ thành công + lịch sử tag
- [ ] Đã đọc runbook và quy trình rollback

**Đối chiếu đề bài (Phần 4C + rollback):**

| Yêu cầu | Đáp ứng |
|---|---|
| Rollback capability (manual or automated) | Cả hai, đã diễn tập |
| Document deployment process | `docs/DEPLOYMENT_RUNBOOK.md` |
| Create deployment runbook | `docs/DEPLOYMENT_RUNBOOK.md` |
| Track deployment history | Tag `prod-*`, tab Deployments, báo cáo |
| Monitor deployment success rates | `deploy-report.yml` (hằng tuần) |
| Document rollback procedures | `docs/ROLLBACK.md` |

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| SonarCloud Quality Gate đỏ (Security Rating) ở PR này: S8705, S8707 trong `deploy_report.py`, S8233 trong `rollback.yml` | Bản cũ của script đưa `--limit`/`--output` thẳng vào lệnh/đường dẫn; `rollback.yml` cấp `contents: write` cho cả workflow | Dùng bản hiện tại: `gh` gọi với hằng số, `--save` thay `--output`; `rollback.yml` chỉ cấp quyền ghi cho job `rollback` |
| `gh workflow run rollback.yml` báo `HTTP 404: Not Found (.../workflows/rollback.yml)` hoặc `could not find any workflows named rollback.yml` | `rollback.yml` chưa có trên `develop` (nhánh mặc định) và/hoặc `main` | Làm hết Bước 5: merge PR vào `develop`, phát hành lên `main`, duyệt production; rồi `gh workflow list` phải thấy *Rollback (thủ công)* |
| `Workflow does not have 'workflow_dispatch' trigger` với `--ref main` | File trên `main` chưa có / chưa phát hành | Phát hành `develop → main` (Bước 5) |
| Diễn tập Bước 6 nhưng không có bước rollback | Chưa có tag `prod-*` nào → không có baseline/backup | Phải có ít nhất 1 lần deploy production thành công trước |
| Job `validate` của rollback đỏ: `Không tìm thấy tag` | Gõ sai tag | Xem danh sách tag (Bước 7) |
| Bước 2 (baseline) lỗi khi rollback | Tag quá cũ thiếu file | Chọn tag tạo từ file 03 trở đi |
| Báo cáo ghi `Không đọc được lịch sử ... HTTP 404` | Workflow chưa từng chạy / chưa có trên nhánh mặc định | Đợi có lần chạy đầu tiên |
| Báo cáo không có lịch sử tag | Checkout thiếu tag | `deploy-report.yml` đã dùng `fetch-depth: 0`; kiểm tra lại file |

---

## Tiếp theo

→ **`08_TAI_LIEU_VA_DEMO.md`**: hoàn thiện tài liệu (kiến trúc, setup guide, troubleshooting, kịch bản demo), sắp xếp lại repo → **mốc 100 điểm**.
