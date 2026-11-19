{% docs __overview__ %}
# DataOps pipeline: AdventureWorks → dbt → Airflow

Dự án biến đổi dữ liệu bán hàng của **AdventureWorks2014** (SQL Server) theo kiến trúc **medallion**:

| Tầng | Schema | Materialization | Vai trò |
|---|---|---|---|
| **Bronze** | `<env>_bronze` | view | 1-1 với bảng nguồn: đổi tên cột, ép kiểu, làm sạch chuỗi |
| **Silver** | `<env>_silver` | table / incremental | Join nhiều bảng bronze, áp dụng logic nghiệp vụ |
| **Gold** | `<env>_gold` | table | Bảng tổng hợp sẵn sàng cho báo cáo |

`<env>` là môi trường: `dev`, `staging`, `prod` (hoặc `ci` khi chạy kiểm thử tự động).

**Cách xem lineage:** bấm biểu tượng sơ đồ ở góc dưới bên phải trang này.

Mã nguồn: [github.com/farols1505/dbt-airflow-dataops](https://github.com/farols1505/dbt-airflow-dataops)
{% enddocs %}


{% docs order_status %}
Trạng thái đơn hàng:

| Giá trị | Ý nghĩa |
|---|---|
| 1 | In process — đang xử lý |
| 2 | Approved — đã duyệt |
| 3 | Backordered — chờ hàng |
| 4 | Rejected — bị từ chối |
| 5 | Shipped — đã giao |
| 6 | Cancelled — đã hủy |
{% enddocs %}


{% docs modified_at %}
Thời điểm bản ghi được cập nhật lần cuối ở hệ thống nguồn (cột `ModifiedDate`).
Dùng cho kiểm tra độ tươi dữ liệu (source freshness) và xử lý incremental.
{% enddocs %}


{% docs rfm_model %}
Phân khúc khách hàng theo mô hình **RFM** (chỉ gồm khách đã từng mua):

- **R — Recency:** mua gần đây hay đã lâu.
- **F — Frequency:** mua bao nhiêu đơn.
- **M — Monetary:** chi tiêu bao nhiêu.

Mỗi tiêu chí được chấm 1–4 điểm theo tứ phân vị, rồi suy ra phân khúc:

| Phân khúc | Điều kiện |
|---|---|
| Champions | R ≥ 3, F ≥ 3, M ≥ 3 |
| Loyal | R ≥ 3, F ≥ 2 |
| Promising | R ≥ 3 |
| Needs Attention | R = 2 |
| At Risk | R = 1 nhưng F ≥ 3 hoặc M ≥ 3 |
| Hibernating | Còn lại |
{% enddocs %}
