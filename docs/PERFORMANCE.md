# Tối ưu hiệu năng

## 1. Các kỹ thuật đã áp dụng

| Kỹ thuật | Áp dụng ở | Tác dụng |
|---|---|---|
| **View cho bronze** | 7 model bronze | Không tốn dung lượng, luôn đọc dữ liệu mới nhất; bronze chỉ đổi tên/ép kiểu nên đọc qua view rất nhẹ |
| **Table cho silver/gold** | 3 silver, 4 gold | Gold/dashboard đọc bảng đã tính sẵn thay vì tính lại join mỗi lần truy vấn |
| **Clustered columnstore index** | Mọi bảng (dbt-sqlserver tạo mặc định) | Nén dữ liệu theo cột, truy vấn tổng hợp (`SUM`, `COUNT`, `GROUP BY`) ở gold nhanh hơn nhiều so với lưu theo dòng |
| **Incremental** | `slvr_sales_orders` (~121 nghìn dòng, bảng lớn nhất) | Lần chạy sau chỉ xử lý các dòng có `modified_at` mới hơn dữ liệu đã có (`delete+insert` theo `order_detail_id`) |
| **Nonclustered index** | `slvr_sales_orders(customer_id)`, `(product_id)` | Tăng tốc tra cứu/join theo từng khách hàng, sản phẩm |
| **Chạy theo tầng** | DAG Airflow, `--select path:models/<tầng>` | Lỗi ở tầng nào dừng ở tầng đó, không lãng phí tài nguyên build tầng sau |

## 2. Số liệu đo

Đo bằng script `scripts/benchmark_incremental.sh` (máy local, target `dev`):

```bash
./scripts/benchmark_incremental.sh
```

Kết quả đo ngày 2026-11-13 (target `dev`, laptop phát triển, SQL Server trong Docker):

| Trường hợp | Thời gian (giây) |
|---|---|
| Full refresh (121 317 dòng) | 1.15 |
| Incremental — không có dữ liệu mới | 0.28 |
| Incremental — sau khi có dữ liệu mới (20 đơn hàng = 50 dòng) | 0.19 |

**Nhận xét:** incremental nhanh hơn full refresh khoảng **4–6 lần** ngay cả với bộ dữ liệu nhỏ. Thời gian full refresh tăng theo **tổng** dữ liệu, còn incremental chỉ tăng theo dữ liệu **mới** → với dữ liệu thật tăng thêm mỗi ngày, chênh lệch càng lớn. Số liệu dao động vài phần trăm giữa các lần đo; chạy lại script để cập nhật.

## 3. Khi nào cần full refresh?

Incremental chỉ thêm/cập nhật dòng, không tự sửa cấu trúc bảng. Chạy lại toàn bộ khi:
- đổi logic hoặc thêm/bớt cột trong `slvr_sales_orders`;
- nghi ngờ dữ liệu bị lệch.

```bash
docker compose exec dbt dbt build --full-refresh --select slvr_sales_orders+
```

Deploy trên GitHub Actions luôn dùng `dbt run --full-refresh` (database tạm, cần build lại toàn bộ để an toàn khi cấu trúc thay đổi).
