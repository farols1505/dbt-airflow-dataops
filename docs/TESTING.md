# Chiến lược kiểm thử dữ liệu

Dự án có **140+ test dbt**, chạy ở 3 nơi:

| Nơi chạy | Khi nào | Lệnh |
|---|---|---|
| Máy local | Khi phát triển | `docker compose exec dbt dbt build` |
| CI (`ci.yml`, job `dbt-build`) | Mọi Pull Request | `dbt build --target ci` trên SQL Server tạm |
| CD (`_deploy.yml`) | Mỗi lần deploy | `dbt test --target <env>`; lỗi ở production → rollback tự động |
| Airflow (`dbt_pipeline`) | Hằng ngày | `dbt test` sau từng tầng + test nghiệp vụ cuối pipeline |

---

## 1. Schema tests (test có sẵn của dbt)

| Loại | Áp dụng cho | Ví dụ |
|---|---|---|
| `not_null` + `unique` | Khóa chính của **mọi** model và mọi bảng nguồn | `brnz_customer.customer_id`, `gld_sales_summary.order_date` |
| `relationships` | Khóa ngoại | `slvr_sales_orders.customer_id` → `slvr_customers`, `brnz_sales_order_detail.product_id` → `brnz_product` |
| `accepted_values` | Cột có miền giá trị cố định | `order_status` ∈ 1..6, `order_channel` ∈ {Online, Offline}, `product_line` ∈ {R, M, T, S}, `customer_segment` |
| `dbt_utils.unique_combination_of_columns` | Khóa ghép | (`sales_order_id`, `order_detail_id`) |
| `dbt_utils.expression_is_true` | Quy tắc giữa các cột | `online_orders + offline_orders = total_orders` |
| `dbt_utils.accepted_range` | Khoảng giá trị | `profit_margin_pct` ≤ 100 |

## 2. Generic tests tự viết (`dbt/tests/generic/`)

| Test | Kiểm tra | Dùng cho |
|---|---|---|
| `positive_value` | Giá trị > 0 (hoặc ≥ 0 với `allow_zero: true`) | số lượng, đơn giá, thành tiền, doanh thu, số ngày giao hàng |
| `valid_date_range` | Ngày trong khoảng `[min_date, max_date]`, mặc định không ở tương lai | `order_date` |
| `date_not_before` | Ngày ở cột này không trước cột so sánh trên cùng dòng | `ship_date ≥ order_date`, `due_date ≥ order_date`, `sell_end_date ≥ sell_start_date` |
| `row_count_greater_than` | Bảng có nhiều hơn N dòng (bắt lỗi "bảng rỗng") | mọi bảng gold |

## 3. Singular tests — đối soát nghiệp vụ (`dbt/tests/`)

| Test | Quy tắc nghiệp vụ |
|---|---|
| `assert_gold_revenue_matches_silver` | Tổng doanh thu gold (theo ngày) = tổng thành tiền silver (sai số < 0,01) |
| `assert_customer_orders_match_silver` | Tổng số đơn của mọi khách ở gold = số đơn khác nhau ở silver |
| `assert_every_buyer_has_segment` | Mọi khách đã mua đều có phân khúc RFM |

Các test này bật `store_failures`: dòng vi phạm được lưu vào schema `<env>_dbt_test__audit` để điều tra.

## 4. Source freshness

| Cấu hình | Giá trị | Ý nghĩa |
|---|---|---|
| `loaded_at_field` | `ModifiedDate` | Thời điểm bản ghi được cập nhật ở hệ thống nguồn |
| `warn_after` | 24 giờ | Quá 1 chu kỳ nạp → cảnh báo |
| `error_after` | 48 giờ | Lỡ ít nhất 1 lần nạp → lỗi, dừng pipeline |
| Độ trễ kỳ vọng | < 24 giờ (ghi trong `meta.expected_latency`) | Hệ thống nguồn được nạp hằng ngày |

AdventureWorks là dữ liệu tĩnh (2011–2014) nên freshness luôn lỗi. Macro `simulate_new_data` mô phỏng một lần nạp dữ liệu mới (cập nhật `ModifiedDate` cho 20 đơn hàng mới nhất và các bản ghi liên quan). CI và DAG Airflow chạy macro này trước `dbt source freshness`.

```bash
docker compose exec dbt dbt source freshness                 # trước: ERROR STALE
docker compose exec dbt dbt run-operation simulate_new_data
docker compose exec dbt dbt source freshness                 # sau: PASS
```

## 5. Mức độ nghiêm trọng

- Mặc định `severity: error` (khai báo trong `dbt_project.yml`): test lỗi → `dbt build` lỗi → CI đỏ / deploy rollback / task Airflow lỗi.
- Freshness có 2 mức riêng: `warn_after` (cảnh báo) và `error_after` (lỗi).

## 6. Thống kê

Đếm lại bất cứ lúc nào:

```bash
docker compose exec dbt dbt -q ls --resource-type test | wc -l                          # 143
docker compose exec dbt dbt -q ls --resource-type test --select test_type:singular     # 3 test nghiệp vụ
```
