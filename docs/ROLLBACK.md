# Quy trình rollback

Có **2 cơ chế** rollback cho production.

| | Rollback tự động | Rollback thủ công |
|---|---|---|
| Khi nào | Deploy production lỗi ở bước run / test / health check | Deploy đã thành công nhưng phát hiện lỗi sau đó |
| Ai kích hoạt | Workflow tự làm | Người vận hành chạy workflow **Rollback (thủ công)** |
| Quay về | Dữ liệu ngay trước lần deploy (backup) | Code + dữ liệu của một tag `prod-*` cũ bất kỳ |
| Kết quả | Production giữ nguyên phiên bản cũ; không tạo tag | Tag mới `prod-YYYYMMDD-HHMM-rollback` trỏ về commit cũ |

---

## 1. Rollback tự động (dữ liệu)

Nằm trong `.github/workflows/_deploy.yml`, chỉ áp dụng cho production:

1. **Trước deploy:** dựng lại phiên bản prod đang chạy (tag `prod-*` mới nhất), rồi `dbt run-operation backup_layers` sao chép mọi bảng `prod_silver`, `prod_gold` sang `prod_silver__backup`, `prod_gold__backup`.
2. **Deploy lỗi** (run, test hoặc health check): `dbt run-operation restore_layers` chép lại bảng từ backup, xóa bảng mới do lần deploy lỗi tạo ra, rồi chạy health check lại.
3. Job vẫn **đỏ** (để mọi người biết có lỗi), Job Summary và Discord ghi *"đã tự động rollback"*.

**Diễn tập** (không cần làm hỏng code):

```bash
gh workflow run deploy.yml --ref main -f simulate_failure=true
# → duyệt production → bước "Diễn tập: cố ý gây lỗi" đỏ → bước "Rollback tự động" xanh
```

## 2. Rollback thủ công (phiên bản)

### Bước 1 — Chọn tag cần quay về

```bash
git fetch --tags
git tag -l 'prod-*' --sort=-creatordate --format='%(refname:short)  %(creatordate:short)  %(contents:subject)' | head
```

### Bước 2 — Chạy workflow

```bash
gh workflow run rollback.yml -f tag=prod-20261113-1530 -f reason="Doanh thu gold bị nhân đôi"
```

hoặc GitHub → Actions → **Rollback (thủ công)** → *Run workflow* → nhập `tag` + `reason`.

### Bước 3 — Duyệt và theo dõi

1. Job `validate` kiểm tra tag tồn tại.
2. Job `rollback` chờ duyệt (Environment `production`) → **Approve and deploy**.
3. Workflow deploy lại đúng code của tag đó (vẫn đủ các bước backup → run → test → health check).
4. Thành công → tag mới `prod-...-rollback` + thông báo Discord.

### Bước 4 — Sau rollback

- Tag mới nhất giờ trỏ về commit cũ → lần deploy production kế tiếp coi đây là phiên bản đang chạy.
- Sửa lỗi gốc trên nhánh `fix/...`, đi lại quy trình phát hành bình thường.
- Ghi lại sự cố: thời điểm, triệu chứng, tag bị rollback, nguyên nhân, cách sửa.

## 3. Giới hạn

- Backup chỉ giữ **1 bản** (ngay trước lần deploy gần nhất).
- Bronze là view, không backup (được tạo lại từ code).
- Trên GitHub Actions database là tạm thời; vì vậy bước "dựng lại phiên bản prod đang chạy" là cần thiết để backup/restore có ý nghĩa. Với một production thật (database lâu dài), bỏ bước này và backup trực tiếp.
