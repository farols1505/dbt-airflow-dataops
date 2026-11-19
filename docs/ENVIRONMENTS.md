# Môi trường triển khai: dev · staging · production

## 1. Tổng quan

| Môi trường | GitHub Environment | dbt target | Schema | Deploy khi | Duyệt thủ công |
|---|---|---|---|---|---|
| **dev** | `dev` | `dev` | `dev_bronze`, `dev_silver`, `dev_gold` | Merge vào `develop` | Không |
| **staging** | `staging` | `staging` | `staging_*` | Merge vào `main` | Không |
| **production** | `production` | `prod` | `prod_*` | Sau khi staging thành công | **Có** (required reviewer) |
| *(CI)* | — | `ci` | `ci_*` | Mọi Pull Request | — |

```
feature/* ──PR──► develop ──► [dev]
                     │
                     └──PR──► main ──► [staging] ──(Approve)──► [production] ──► tag prod-YYYYMMDD-HHMM
```

## 2. Cách tách môi trường

- **Cùng database, khác schema.** `dbt/profiles.yml` khai báo 4 target giống nhau, chỉ khác `schema`. Macro `dbt/macros/generate_schema_name.sql` ghép schema của target với tên tầng → `prod_gold`, `dev_gold`...
  (Adapter dbt-sqlserver mặc định bỏ qua tiền tố target; macro này khôi phục hành vi chuẩn của dbt.)
- **Chọn môi trường:** biến `DBT_TARGET` trong `.env` (mặc định `dev`), hoặc tham số `--target`, hoặc `params.target` khi trigger DAG Airflow.
- **Trên GitHub Actions:** mỗi lần deploy dựng một SQL Server tạm (database bị xóa khi job kết thúc). Môi trường thể hiện qua: GitHub Environment (secret riêng, luật duyệt, lịch sử deploy) + dbt target (schema riêng).

## 3. Cấu hình GitHub Environments

| Environment | Secret riêng | Luật bảo vệ |
|---|---|---|
| `dev` | `DBT_ENV_SECRET_PASSWORD` (tùy chọn) | Chỉ nhánh được bảo vệ |
| `staging` | `DBT_ENV_SECRET_PASSWORD` (tùy chọn) | Chỉ nhánh được bảo vệ |
| `production` | `DBT_ENV_SECRET_PASSWORD`, `SA_PASSWORD` (tùy chọn) | Chỉ nhánh được bảo vệ + **người duyệt bắt buộc** |

Secret cấp repo: `NOTIFY_WEBHOOK_URL` (Discord). Không khai báo secret mật khẩu thì workflow tự sinh mật khẩu ngẫu nhiên (`scripts/ci/create_env.sh`).

Xem cấu hình hiện tại:

```bash
gh api repos/{owner}/{repo}/environments --jq '.environments[] | {name, rules: [.protection_rules[].type]}'
```

## 4. Lịch sử deploy theo môi trường

- GitHub → repo → **Environments** (cột bên phải trang repo) → chọn môi trường → danh sách các lần deploy.
- Production: mỗi lần thành công có một tag `prod-*` (`git tag -l 'prod-*' --sort=-creatordate`).
- Báo cáo tổng hợp: workflow **Deployment Report** (xem `docs/DEPLOYMENT_RUNBOOK.md`).
