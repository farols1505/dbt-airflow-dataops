# Runbook — Quy trình deploy

Tài liệu vận hành: **làm gì, theo thứ tự nào, khi gặp sự cố thì xử lý ra sao.**

---

## 1. Deploy lên DEV (hằng ngày)

1. Làm việc trên nhánh `feature/...` → mở Pull Request vào `develop`.
2. Đợi CI xanh (`lint`, `dag-tests`, `dbt-build`, `validate-pr`).
3. **Squash and merge** → workflow **Deploy** tự chạy job `dev`.
4. Kiểm tra: Actions → Deploy → lần chạy mới nhất → job *Deploy → dev* xanh; Discord nhận thông báo ✅.

## 2. Phát hành lên STAGING → PRODUCTION

| Bước | Ai | Việc |
|---|---|---|
| 1 | Người phát hành | `gh pr create --base main --head develop --title "chore(release): <mô tả>"` |
| 2 | — | CI chạy trên PR phát hành; phải xanh |
| 3 | Người phát hành | Merge bằng **Create a merge commit** (`gh pr merge --merge`) |
| 4 | Tự động | Job `staging` deploy lên staging |
| 5 | **Người duyệt** | Actions → lần chạy Deploy → **Review deployments** → chọn `production` → **Approve and deploy** |
| 6 | Tự động | Job `production`: dựng lại bản prod cũ → backup → run → test → health check → tag `prod-*` → thông báo |
| 7 | Người phát hành | Kiểm tra: tag mới (`git fetch --tags && git tag -l 'prod-*' --sort=-creatordate \| head -3`), Discord ✅ |

**Checklist trước khi duyệt production:**
- [ ] Job staging xanh, xem tóm tắt dbt (số test pass/warn).
- [ ] Không có cảnh báo freshness bất thường.
- [ ] Biết phiên bản sẽ thay thế (dòng "Phiên bản production hiện tại" trong Job Summary).

## 3. Các bước bên trong một lần deploy (`_deploy.yml`)

| # | Bước | Lỗi thì sao |
|---|---|---|
| 0 | Dựng SQL Server tạm + dbt, restore AdventureWorks | Job đỏ; xem bước "Log container khi lỗi" |
| 1 | **Pre-deploy validation**: `dbt debug`, `parse`, `compile` | Dừng ngay, chưa đụng tới dữ liệu |
| 2 | *(prod)* Dựng lại phiên bản prod đang chạy (tag `prod-*` mới nhất) | Dừng, chưa deploy |
| 3 | *(prod)* **Backup** silver + gold → schema `*__backup` | Dừng, chưa deploy |
| 4 | `dbt run --full-refresh` | **Rollback tự động** (prod) |
| 5 | `dbt test` | **Rollback tự động** (prod) |
| 6 | **Post-deploy health check**: mọi bảng/view có dữ liệu | **Rollback tự động** (prod) |
| 7 | *(prod)* Gắn tag `prod-YYYYMMDD-HHMM` | — |
| 8 | Tóm tắt dbt, thông báo Discord, upload log (artifact `deploy-logs-<env>`, giữ 30 ngày) | Không ảnh hưởng kết quả deploy |

## 4. Xử lý sự cố

| Tình huống | Xử lý |
|---|---|
| Deploy dev/staging đỏ | Mở log job → sửa trên nhánh `fix/...` → PR vào `develop` → deploy lại |
| Deploy production đỏ, có dòng *"Đã rollback dữ liệu"* | Production vẫn chạy phiên bản cũ. Sửa lỗi qua PR, phát hành lại |
| Deploy production thành công nhưng phát hiện lỗi sau đó | **Rollback thủ công** về tag trước → `docs/ROLLBACK.md` |
| Job production đứng ở *Waiting* | Đang chờ duyệt → *Review deployments* |
| Muốn deploy lại không đổi code | Actions → Deploy → **Run workflow** → chọn nhánh |
| Thông báo Discord không đến | Kiểm tra secret `NOTIFY_WEBHOOK_URL`; bước 8b có dòng `Đã gửi thông báo Discord` hay cảnh báo |

## 5. Giám sát deployment

| Chỉ số | Xem ở đâu |
|---|---|
| Trạng thái hiện tại | Badges trong `README.md` |
| Lịch sử deploy từng môi trường | GitHub → **Environments** |
| Lịch sử phiên bản production | `git tag -l 'prod-*' --sort=-creatordate` |
| Tỉ lệ thành công, thời gian trung bình | Workflow **Deployment Report** (tự chạy sáng thứ Hai; chạy tay: `gh workflow run deploy-report.yml`) |

Mục tiêu: tỉ lệ deploy thành công ≥ 90%; mọi lần production thất bại đều được rollback tự động.
