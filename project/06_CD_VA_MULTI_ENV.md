# 06 — DEPLOY THEO MÔI TRƯỜNG: DEV · STAGING · PRODUCTION

| | |
|---|---|
| **Phần chấm điểm** | Phần 4B nâng cao (8đ: theo môi trường, thông báo, badges, pre/post check) + Phần 4 "Environment management" (5đ) + **Bonus 4** (multi-environment) |
| **Thời gian** | 2–3 giờ |
| **Điều kiện** | Đã xong [`05`](05_AIRFLOW_DAG.md); đã có Discord webhook |
| **Kết quả** | 3 GitHub Environments; production **phải được duyệt** mới deploy; secret riêng theo môi trường; mỗi lần deploy gửi thông báo Discord; phát hành lên production có duyệt + tag |

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Mô hình 3 môi trường](#bước-1--mô-hình-3-môi-trường)
- [Bước 2 — Cấu hình GitHub Environments](#bước-2--cấu-hình-github-environments)
- [Bước 3 — Secrets](#bước-3--secrets)
- [Bước 4 — Commit tài liệu môi trường](#bước-4--commit-tài-liệu-môi-trường)
- [Bước 5 — Phát hành có duyệt: develop → main → production](#bước-5--phát-hành-có-duyệt-develop--main--production)
- [Bước 6 — Xem lịch sử deploy và badges](#bước-6--xem-lịch-sử-deploy-và-badges)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

| File | Trạng thái | Nội dung | Mục đích |
|---|---|---|---|
| `docs/ENVIRONMENTS.md` | Mới | Bảng 3 môi trường (Environment, target, schema, khi nào deploy, duyệt), cách tách môi trường, cấu hình Environments + secrets, cách xem lịch sử | "Environment management", tài liệu |
| `.github/workflows/deploy.yml`, `_deploy.yml`, `scripts/ci/notify.py` | Đã commit ở file 03 | Phần dùng tới ở bước này: `environment:` của từng job, secret theo môi trường, thông báo Discord, tag | Bước này **cấu hình GitHub** để các phần đó có hiệu lực |

Phần lớn công việc ở bước này là **cấu hình trên GitHub** (bằng `gh`), không phải code.

**Kế hoạch commit** (nhánh `docs/environments`): `docs: document deployment environments`.

---

## Bước 1 — Mô hình 3 môi trường

```
feature/* ──PR──► develop ──► [dev]
                     │
                     └──PR──► main ──► [staging] ──(Approve)──► [production] ──► tag prod-YYYYMMDD-HHMM
```

| | dev | staging | production |
|---|---|---|---|
| GitHub Environment | `dev` | `staging` | `production` |
| dbt target → schema | `dev` → `dev_*` | `staging` → `staging_*` | `prod` → `prod_*` |
| Kích hoạt | merge vào `develop` | merge vào `main` | sau khi staging xanh |
| Duyệt thủ công | — | — | **có** |
| Backup + rollback tự động | — | — | **có** |
| Tag phiên bản | — | — | **có** |

**Tách môi trường ở 2 lớp:**
1. **dbt:** mỗi target một bộ schema (`profiles.yml` + macro `generate_schema_name` từ file 02).
2. **GitHub Environment:** secret riêng, luật bảo vệ riêng (ai được duyệt, nhánh nào được deploy), lịch sử deploy riêng.

> Staging dùng để "chạy thử y như production" ngay trước khi lên production. Đây là phần **Bonus 4** (dev/staging/prod); yêu cầu bắt buộc chỉ cần dev + prod.

---

## Bước 2 — Cấu hình GitHub Environments

Ở file 03, GitHub đã **tự tạo** 3 environment khi workflow tham chiếu lần đầu, nhưng **chưa có luật bảo vệ**.

### 2.1. dev và staging: chỉ deploy từ nhánh được bảo vệ

```bash
cd ~/HCMUS/Advanced_DevOps/DataOps/dbt_airflow_project
for ENV in dev staging; do
gh api -X PUT "repos/{owner}/{repo}/environments/$ENV" --input - <<'EOF'
{
  "deployment_branch_policy": { "protected_branches": true, "custom_branch_policies": false }
}
EOF
done
```

### 2.2. production: chỉ nhánh được bảo vệ + bắt buộc người duyệt

```bash
USER_ID=$(gh api user --jq .id)
gh api -X PUT "repos/{owner}/{repo}/environments/production" --input - <<EOF
{
  "wait_timer": 0,
  "prevent_self_review": false,
  "reviewers": [ { "type": "User", "id": $USER_ID } ],
  "deployment_branch_policy": { "protected_branches": true, "custom_branch_policies": false }
}
EOF
```

| Thiết lập | Ý nghĩa |
|---|---|
| `reviewers` = bạn | Job production **dừng chờ** tới khi bạn bấm duyệt |
| `prevent_self_review: false` | Cho phép tự duyệt lần deploy do chính mình kích hoạt |
| `protected_branches: true` | Chỉ `main`/`develop` (đang được bảo vệ) mới deploy được vào môi trường này |

### 2.3. Kiểm tra

```bash
gh api "repos/{owner}/{repo}/environments" --jq '.environments[] | {name, rules: [.protection_rules[].type]}'
```

Mong đợi: `production` có `required_reviewers` và `branch_policy`; `dev`, `staging` có `branch_policy`.

Trên web: **Settings → Environments → production**.

---

## Bước 3 — Secrets

| Secret | Phạm vi | Dùng ở | Bắt buộc? |
|---|---|---|---|
| `NOTIFY_WEBHOOK_URL` | Repo | `notify.py` → Discord sau mỗi deploy/rollback | Nên có |
| `DBT_ENV_SECRET_PASSWORD` | Từng environment | Mật khẩu tài khoản dbt của môi trường đó (`create_env.sh`) | Tùy chọn (không có → sinh ngẫu nhiên) |
| `SA_PASSWORD` | Từng environment | Mật khẩu `sa` của SQL Server tạm | Tùy chọn |

```bash
# Webhook Discord (dán URL khi được hỏi, không hiện ra màn hình)
gh secret set NOTIFY_WEBHOOK_URL

# Mật khẩu dbt riêng cho từng môi trường (chữ + số, có hoa/thường/số)
for ENV in dev staging production; do
  gh secret set DBT_ENV_SECRET_PASSWORD --env "$ENV" --body "Env$(openssl rand -hex 8)Pw1"
done

gh secret list
gh secret list --env production
```

> Vì SQL Server trên GitHub Actions là tạm thời, mật khẩu theo môi trường chủ yếu minh họa **quản lý bí mật theo môi trường** (mỗi môi trường một bộ secret, workflow chỉ đọc được secret của môi trường nó deploy).

Thông báo Discord gồm: trạng thái (✅/❌/đã rollback), môi trường, commit, tag, link tới lần chạy.

---

## Bước 4 — Commit tài liệu môi trường

```bash
git switch develop && git pull
git switch -c docs/environments
git add docs/ENVIRONMENTS.md
git commit -m "docs: document deployment environments"
git push -u origin docs/environments
gh pr create --base develop --title "docs: document deployment environments" \
  --body "Mô tả 3 môi trường dev/staging/production, cách tách môi trường, cấu hình Environments và secrets."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --squash --delete-branch && git switch develop && git pull
```

Merge → Deploy **dev** chạy → lần này Discord nhận thông báo ✅ *Deploy → dev*.

---

## Bước 5 — Phát hành có duyệt: develop → main → production

### 5.1. Mở PR phát hành

```bash
gh pr create --base main --head develop \
  --title "chore(release): dbt medallion refactor, Airflow pipeline and environments" \
  --body "Phát hành: model dbt mới + test đầy đủ (file 04), DAG Airflow (file 05), tài liệu môi trường (file 06)."
sleep 20      # GitHub cần vài giây để tạo check; chạy ngay thì gh báo "no checks reported" và thoát
gh pr checks --watch && gh pr merge --merge
```

> Sau khi merge, GitHub có thể hiện banner vàng *"main had recent pushes — Compare & pull request"*. **Bỏ qua nó**: dự án không bao giờ mở PR `main → develop` (PR đó chỉ chứa merge commit, 0 file thay đổi, và bị `validate-pr` chặn). Điều này đúng cho mọi lần phát hành ở các file sau.

### 5.2. Theo dõi staging

```bash
gh run list --workflow deploy.yml --branch main --limit 1
gh run watch
```

Job `staging / Deploy → staging` chạy; xong thì `production / Deploy → production` chuyển sang **Waiting** (đang chờ duyệt).

### 5.3. Duyệt production

**Cách 1 — trên web:** Actions → lần chạy Deploy → nút **Review deployments** → tick `production` → (ghi chú) → **Approve and deploy**.

**Cách 2 — bằng lệnh:**

```bash
RUN_ID=$(gh run list --workflow deploy.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')
ENV_ID=$(gh api "repos/{owner}/{repo}/environments/production" --jq .id)
gh api -X POST "repos/{owner}/{repo}/actions/runs/$RUN_ID/pending_deployments" \
  -F "environment_ids[]=$ENV_ID" -f state=approved -f comment="Staging xanh, đã kiểm tra tóm tắt dbt"
```

> **Trước khi duyệt**, mở Summary của job staging: bảng dbt (`run`, `test`) có 0 lỗi? Đây là ý nghĩa của bước duyệt.

### 5.4. Production chạy những gì (lần này có đủ các bước)

Vì đã có tag `prod-*` từ file 03, lần này production chạy **đủ** các bước:

| Bước | Kết quả mong đợi |
|---|---|
| 1. Pre-deploy validation | xanh |
| 2. Dựng lại phiên bản production đang chạy (tag cũ) | xanh, log: `▶ Dựng phiên bản production hiện tại: prod-...` |
| 3. Backup | xanh, log: `💾 prod_gold.gld_... → prod_gold__backup...` |
| 4–6. run, test, health check | xanh |
| ↩️ Rollback tự động | *skipped* (không có lỗi) |
| 7. Gắn tag | `prod-YYYYMMDD-HHMM` mới |
| 8. Thông báo | Discord ✅ *Deploy → production: thành công* |

```bash
git fetch --tags && git tag -l 'prod-*' --sort=-creatordate
```

Giờ có 2 tag: phiên bản ở file 03 và phiên bản vừa phát hành.

---

## Bước 6 — Xem lịch sử deploy và badges

- **Lịch sử theo môi trường:** trang repo → cột phải **Deployments** → chọn `production` / `staging` / `dev`.
- **Badges** (đầu `README.md`, đã có từ file 03): `CI`, `Deploy (develop → dev)`, `Deploy (main → staging, production)` đều xanh.

---

## Checklist hoàn thành

- [ ] 3 environment có luật: `production` có `required_reviewers` + `branch_policy`
- [ ] Secret `NOTIFY_WEBHOOK_URL` (repo) + `DBT_ENV_SECRET_PASSWORD` (3 environment)
- [ ] PR `docs/environments` đã merge, Discord nhận thông báo deploy dev
- [ ] Phát hành `develop → main`: staging xanh → **đã duyệt** → production xanh, đủ bước backup
- [ ] Có ≥ 2 tag `prod-*`
- [ ] Badges trong README xanh

**Đối chiếu đề bài (Phần 4B nâng cao):**

| Yêu cầu | Đáp ứng |
|---|---|
| Environment-specific deployments (dev vs prod, target khác nhau) | dev / staging / prod, target + schema + secret riêng |
| Deployment notifications | Job Summary + Discord |
| Deployment status badges | README |
| Rollback capability | Có từ file 03, diễn tập ở file 07 |
| Pre-deployment validation | Bước 1 của `_deploy.yml` |
| Post-deployment health checks | Bước 6 của `_deploy.yml` |

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| File vừa commit "biến mất" sau `git switch develop` | `gh pr merge` thất bại (check chưa xong) nên PR **chưa merge**; file chỉ nằm trên nhánh tính năng | Không mất gì: `gh pr checks <số PR> --watch && gh pr merge <số PR> --squash --delete-branch`, rồi `git pull` |
| `gh pr checks --watch` báo `no checks reported on the '...' branch` rồi thoát | Chạy ngay sau `gh pr create`/`git push`, GitHub chưa kịp tạo check (cần ~5 giây) | Đợi vài giây rồi chạy lại; khối lệnh trong hướng dẫn đã có `sleep 20` |
| Sau khi phát hành, GitHub hiện banner *"main had recent pushes — Compare & pull request"*; bấm vào thì PR `main → develop` bị `validate-pr` đỏ | PR ngược chiều, không cần thiết: chỉ chứa merge commit của lần phát hành, **0 file** thay đổi | Bỏ qua banner; nếu đã lỡ mở: `gh pr close <số PR>` |
| `gh api ... environments/production` báo `422` về reviewers | Sai `USER_ID` | `gh api user --jq .id` rồi chạy lại |
| Production chạy luôn không chờ duyệt | Chưa có luật `required_reviewers` | Làm lại Bước 2.2, kiểm tra Bước 2.3 |
| Không thấy nút *Review deployments* | Không phải người duyệt, hoặc job chưa tới production | Đợi staging xong; kiểm tra danh sách reviewers |
| `Branch "xxx" is not allowed to deploy to production` | Chạy workflow từ nhánh không được bảo vệ | Chỉ deploy từ `main` / `develop` |
| Discord không nhận thông báo deploy | Thiếu secret `NOTIFY_WEBHOOK_URL` | `gh secret set NOTIFY_WEBHOOK_URL`; log bước 8b ghi `Chưa cấu hình...` nếu thiếu |
| Bước 0 lỗi `Password validation failed` | Secret mật khẩu quá yếu | Đặt lại theo lệnh ở Bước 3 |
| Bước 2 (dựng lại bản cũ) lỗi | Tag cũ quá cũ, thiếu file cần thiết | Mọi tag tạo từ file 03 trở đi đều dùng được; xem log bước đó |

---

## Tiếp theo

→ **`07_ROLLBACK_VA_GIAM_SAT_DEPLOY.md`**: rollback tự động và thủ công, báo cáo tỉ lệ deploy thành công, runbook (Phần 4C).
