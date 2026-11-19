# Kịch bản demo trực tiếp (15 phút)

## Chuẩn bị (trước buổi demo 30 phút)

- [ ] `docker compose up -d` (+ Grafana: `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d grafana`); `docker compose ps` đều healthy.
- [ ] DAG `dbt_pipeline` đã chạy thành công ít nhất 1 lần hôm nay (để Grafana có số liệu).
- [ ] Mở sẵn các tab trình duyệt: repo GitHub (README), tab Actions, Airflow (:8080), Grafana (:3000), trang lineage (GitHub Pages), Discord.
- [ ] Chuẩn bị sẵn một nhánh demo `feature/demo-change` có thay đổi nhỏ (vd. thêm mô tả cột) — **chưa** mở PR.
- [ ] Terminal ở thư mục dự án, cỡ chữ lớn.
- [ ] Phương án dự phòng: ảnh chụp màn hình các bước (Actions xanh, Airflow Grid, Grafana, Discord) phòng khi mạng/máy chậm.

## Kịch bản

| Phút | Nội dung | Thao tác |
|---|---|---|
| 0–2 | **Bài toán + kiến trúc** | README: badges, sơ đồ kiến trúc; giải thích bronze/silver/gold và 3 môi trường |
| 2–4 | **dbt** | Mở `dbt/models/` (1 model mỗi tầng); `docs/TESTING.md`; chạy `docker compose exec dbt dbt build --select gld_sales_summary` |
| 4–7 | **CI** | `gh pr create --base develop --fill` từ nhánh demo → tab Actions: `lint`, `dag-tests`, `dbt-build`, `validate-pr` chạy song song; mở Job Summary của `dbt-build` |
| 7–9 | **CD + môi trường** | Mở một lần chạy Deploy trên `main` đã có: staging → *Review deployments* → production → tag `prod-*`; Discord có thông báo; tab *Environments* |
| 9–11 | **Airflow** | Trigger `dbt_pipeline` → Grid: chạy theo tầng; mở log 1 task; giải thích retry + callback. Trigger thêm với `simulate_new_data = false` → `source_freshness` lỗi → retry → thông báo Discord |
| 11–12 | **Rollback** | `docs/ROLLBACK.md`; mở lần chạy diễn tập `simulate_failure` (bước rollback xanh) hoặc lần chạy workflow Rollback |
| 12–14 | **Giám sát + lineage** | Grafana: tỉ lệ thành công, thời gian theo task, phân khúc RFM; trang lineage GitHub Pages: bấm vào `gld_customer_segments` xem lineage ngược về nguồn |
| 14–15 | **Khó khăn & bài học** | Xem mục dưới |

## Khó khăn & bài học (gợi ý trình bày)

1. **CI cần database nhưng GitHub không thấy máy local** → dựng SQL Server tạm bằng chính docker-compose của dự án.
2. **Adapter dbt-sqlserver bỏ qua tiền tố target** → mọi môi trường ghi chung schema; phát hiện khi kiểm tra schema, sửa bằng macro `generate_schema_name`.
3. **Airflow trên Linux không gọi được Docker** (`permission denied docker.sock`) → `group_add` với GID của nhóm docker.
4. **Dữ liệu tĩnh làm freshness luôn lỗi** → mô phỏng lần nạp dữ liệu (`simulate_new_data`).
5. **Database CI/CD là tạm thời** → để rollback có ý nghĩa, dựng lại phiên bản prod đang chạy trước khi backup.
6. **Package dbt_utils không tương thích hoàn toàn với SQL Server** (test `expression_is_true` lỗi 4511 vì dbt-sqlserver bọc test trong `CREATE VIEW`) → viết bản riêng cho SQL Server và dùng `dispatch` để dbt ưu tiên bản của dự án.
7. Bài học: tự động hóa sớm (CI trước, model sau) giúp mọi thay đổi sau đó đều được kiểm tra; và phải **chạy thử trên hệ thống thật** — các lỗi 2, 3, 6 chỉ lộ ra khi chạy thật.

## Câu hỏi có thể gặp

| Câu hỏi | Ý trả lời |
|---|---|
| Vì sao bronze là view? | Chỉ đổi tên/ép kiểu, không tốn dung lượng, luôn mới nhất |
| Incremental hoạt động thế nào? | Lọc `modified_at` > max hiện có, `delete+insert` theo `order_detail_id`; số liệu ở `docs/PERFORMANCE.md` |
| Prod trên GitHub Actions có thật không? | Database tạm; môi trường thể hiện qua GitHub Environment (secret, duyệt, lịch sử) + schema riêng. Thật sự production cần database lâu dài — chỉ cần đổi `DBT_SERVER` |
| Làm sao biết deploy nào đang chạy ở prod? | Tag `prod-*` mới nhất; Deployment Report |
