# 04 — DBT MODELS VÀ KIỂM THỬ DỮ LIỆU

| | |
|---|---|
| **Phần chấm điểm** | Phần 1 — dbt Data Models (25đ) + Phần 2 — Automated Testing (20đ) |
| **Thời gian** | 5–7 giờ |
| **Điều kiện** | Đã xong [`03`](03_CI_VA_DEPLOY_CO_BAN.md) (CI chạy trên mọi PR) |
| **Kết quả** | 7 bronze + 3 silver + 4 gold, mọi model/cột có mô tả; 143 test (schema, 4 generic tự viết, 3 singular nghiệp vụ, test nguồn); freshness cho mọi nguồn; incremental + index; tài liệu kiểm thử & hiệu năng |

> 💡 **Vì sao Phần 1 và Phần 2 chung một file?** dbt bắt buộc mô tả và test của một model nằm **cùng một file YAML**. Model mới và test của chúng vì vậy phải được commit cùng nhau.

> 📦 Các file đã được tạo sẵn. File này giải thích chúng, hướng dẫn **chạy thử trên máy trước**, rồi commit.

---

## Mục lục

- [Tổng quan: các file của bước này](#tổng-quan-các-file-của-bước-này)
- [Bước 1 — Những gì thay đổi so với model gốc](#bước-1--những-gì-thay-đổi-so-với-model-gốc)
- [Bước 2 — Nguồn dữ liệu và freshness](#bước-2--nguồn-dữ-liệu-và-freshness)
- [Bước 3 — Tầng bronze](#bước-3--tầng-bronze)
- [Bước 4 — Tầng silver](#bước-4--tầng-silver)
- [Bước 5 — Tầng gold](#bước-5--tầng-gold)
- [Bước 6 — Tài liệu model](#bước-6--tài-liệu-model)
- [Bước 7 — Kiểm thử](#bước-7--kiểm-thử)
- [Bước 8 — Chạy thử trên máy](#bước-8--chạy-thử-trên-máy)
- [Bước 9 — Đo hiệu năng](#bước-9--đo-hiệu-năng)
- [Bước 10 — Commit và Pull Request](#bước-10--commit-và-pull-request)
- [Checklist hoàn thành](#checklist-hoàn-thành)
- [Lỗi thường gặp](#lỗi-thường-gặp)

---

## Tổng quan: các file của bước này

### File mới

| File | Nội dung | Mục đích |
|---|---|---|
| `dbt/models/bronze/_sources.yml` | 3 source (`sales`, `production`, `person`) = 7 bảng; `loaded_at_field: ModifiedDate`, freshness 24h/48h, `meta.expected_latency`; test `not_null` + `unique` khóa chính của bảng nguồn | Khai báo nguồn duy nhất (thay 2 file trùng lặp cũ) + **source freshness** |
| `dbt/models/bronze/brnz_*.sql` (7 file) | `brnz_sales_order_header`, `brnz_sales_order_detail`, `brnz_customer`, `brnz_person`, `brnz_product`, `brnz_product_subcategory`, `brnz_product_category` | **1 model / 1 bảng nguồn**, chỉ đổi tên + ép kiểu + trim |
| `dbt/models/bronze/_bronze__models.yml` | Mô tả mọi cột + test của 7 model bronze | Tài liệu + kiểm thử |
| `dbt/models/silver/_silver__models.yml` | Mô tả + test của 3 model silver | |
| `dbt/models/gold/_gold__models.yml` | Mô tả + test của 4 model gold | |
| `dbt/models/gold/gld_customer_segments.sql` | Phân khúc khách hàng RFM | Model gold thứ 4, hấp dẫn khi demo |
| `dbt/models/docs.md` | Doc blocks: trang chủ tài liệu (`__overview__`), trạng thái đơn hàng, `modified_at`, mô hình RFM | Mô tả dài, dùng lại nhiều nơi |
| `dbt/tests/generic/*.sql` (4 file) | `positive_value`, `valid_date_range`, `date_not_before`, `row_count_greater_than` | **≥ 3 custom generic tests** |
| `dbt/tests/assert_*.sql` (3 file) | Đối soát doanh thu gold/silver, số đơn gold/silver, mọi khách đã mua có phân khúc | **Singular tests** nghiệp vụ |
| `dbt/macros/ops/simulate_new_data.sql` | Cập nhật `ModifiedDate = now` cho 20 đơn hàng mới nhất + bản ghi liên quan (tạm tắt trigger) | Freshness có ý nghĩa với dữ liệu tĩnh |
| `dbt/macros/compat/sqlserver__test_expression_is_true.sql` | Bản SQL Server của test `dbt_utils.expression_is_true`: `select 1 as failed_row` thay vì `select 1` | Bản gốc lỗi trên SQL Server (xem Bước 7) |
| `scripts/benchmark_incremental.sh` | Đo thời gian full refresh vs incremental của `slvr_sales_orders` | Số liệu cho tiêu chí "Model performance" |
| `docs/TESTING.md` | Chiến lược kiểm thử, danh sách test, freshness, mức độ nghiêm trọng | "Test documentation" |
| `docs/PERFORMANCE.md` | Kỹ thuật tối ưu + bảng số liệu (bạn điền) | Tài liệu hiệu năng |

### File sửa

| File | Thay đổi |
|---|---|
| `dbt/dbt_project.yml` | Thêm `tags` theo tầng, chú thích lý do chọn materialization, `data_tests: +severity: error`, cấu hình `dispatch` cho dbt_utils |
| `dbt/models/silver/slvr_*.sql` (3 file) | Viết lại theo bronze mới; `slvr_sales_orders` chuyển sang **incremental** + 2 index |
| `dbt/models/gold/gld_*.sql` (3 file) | Sửa lỗi logic, thêm cột |

### File xóa

| File | Lý do |
|---|---|
| `dbt/models/sources.yml` | Source `raw` trùng lặp, trỏ sai schema `dbo` |
| `dbt/models/bronze/src_adventureworks.yml`, `bronze/schema.yml`, `silver/schema.yml`, `gold/schema.yml` | Thay bằng `_sources.yml`, `_<tầng>__models.yml` |
| `dbt/models/bronze/brnz_customers.sql`, `brnz_products.sql`, `brnz_sales_orders.sql` | Bronze cũ join nhiều bảng → sai nguyên tắc tầng |
| `dbt/models/bronze/brnz_example.sql` | File mẫu thừa |

---

## Bước 1 — Những gì thay đổi so với model gốc

| # | Vấn đề ở model gốc | Ảnh hưởng điểm | Đã sửa |
|---|---|---|---|
| 1 | Bronze **join** nhiều bảng (`brnz_customers` join `Person`...) | "Proper layering" (8đ) | Bronze 1-1 với bảng nguồn; join chuyển lên silver |
| 2 | 2 file source trùng; source `raw` sai schema | Code rác | 1 file `_sources.yml` |
| 3 | `brnz_example.sql` thừa | Code rác | Xóa |
| 4 | `avg_order_value` = trung bình **dòng** sản phẩm | Sai logic (10đ) | = doanh thu / số **đơn** |
| 5 | `online_orders`, `offline_orders` đếm **dòng** | Sai logic | Đếm `distinct sales_order_id` |
| 6 | `orders_with_discount` đếm dòng | Sai logic | Đếm đơn có giảm giá |
| 7 | Chỉ có `not_null`/`unique`, thiếu mô tả cột | Phần 2 + tài liệu | 143 test, mô tả mọi cột |
| 8 | Không có freshness | 5đ | Freshness cho cả 7 bảng nguồn |

---

## Bước 2 — Nguồn dữ liệu và freshness

`dbt/models/bronze/_sources.yml` khai báo 3 source theo schema của AdventureWorks:

| Source | Schema | Bảng |
|---|---|---|
| `sales` | `Sales` | `SalesOrderHeader`, `SalesOrderDetail`, `Customer` |
| `production` | `Production` | `Product`, `ProductSubcategory`, `ProductCategory` |
| `person` | `Person` | `Person` |

**Freshness** (khai báo ở cấp source, áp dụng cho mọi bảng):

```yaml
loaded_at_field: ModifiedDate
freshness:
  warn_after: {count: 24, period: hour}    # quá 1 chu kỳ nạp hằng ngày → cảnh báo
  error_after: {count: 48, period: hour}   # lỡ ≥ 1 lần nạp → lỗi
meta:
  expected_latency: "Nạp hằng ngày; dữ liệu mới nhất không cũ hơn 24 giờ"
```

**Mô phỏng dữ liệu mới** (`dbt/macros/ops/simulate_new_data.sql`): AdventureWorks dừng ở năm 2014, nên freshness luôn lỗi. Macro chọn 20 đơn hàng mới nhất và cập nhật `ModifiedDate = GETDATE()` cho đơn hàng, dòng chi tiết, khách hàng, người, sản phẩm, danh mục liên quan. Macro **tạm tắt trigger** của AdventureWorks trong lúc cập nhật, để trigger không tự sửa các dữ liệu khác (vd. tổng tiền đơn hàng).

Ai gọi macro này: CI (trước `dbt source freshness`), DAG Airflow (task `simulate_ingestion`), và bạn khi demo.

---

## Bước 3 — Tầng bronze

Mẫu chung của mọi model bronze (vd. `brnz_customer.sql`):

```sql
with source as (
    select * from {{ source('sales', 'Customer') }}
),

renamed as (
    select
        cast(CustomerID as int) as customer_id,       -- snake_case + ép kiểu rõ ràng
        ...
        trim(AccountNumber) as account_number,        -- bỏ khoảng trắng thừa
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
```

Quy tắc: **không join, không logic nghiệp vụ**; tiền tệ `money` → `decimal(19, 4)`; ngày → `date`; chuỗi rỗng → `NULL` (`nullif(trim(x), '')`); cột `nchar(2)` như `ProductLine` (`'R '`) được trim; bỏ cột XML và `rowguid`. Materialization: **view** (khai báo trong `dbt_project.yml`).

---

## Bước 4 — Tầng silver

| Model | Join | Logic nghiệp vụ |
|---|---|---|
| `slvr_customers` | customer + person | `customer_type` (Individual/Store), `full_name` (`'Store #<id>'` nếu là cửa hàng không có người liên hệ) |
| `slvr_products` | product + subcategory + category | `price_tier` (Not for sale / Budget / Mid-range / Premium), `is_active`, giá trị mặc định `N/A`, `Uncategorized` |
| `slvr_sales_orders` | order detail + header | `order_status_name`, `order_channel` (Online/Offline), `gross_amount`, `discount_amount`, `has_discount`, `days_to_ship` |

**`slvr_sales_orders` là incremental** (bảng lớn nhất, ~121 nghìn dòng):

```sql
{{ config(materialized='incremental', unique_key='order_detail_id',
          incremental_strategy='delete+insert',
          post_hook=["{{ create_nonclustered_index(columns=['customer_id']) }}", ...]) }}
...
{% if is_incremental() %}
    where joined.modified_at > (select max(existing.modified_at) from {{ this }} as existing)
{% endif %}
```

- Lần đầu (hoặc `--full-refresh`): build toàn bộ.
- Lần sau: chỉ lấy dòng có `modified_at` mới hơn dữ liệu đã có → xóa bản cũ cùng `order_detail_id` rồi chèn bản mới.
- `modified_at` lấy giá trị **mới hơn** giữa header và detail → đổi header cũng được cập nhật.
- `create_nonclustered_index` là macro có sẵn của dbt-sqlserver; tạo index cho cột hay dùng để join/tra cứu.

---

## Bước 5 — Tầng gold

| Model | Mức chi tiết | Nội dung chính |
|---|---|---|
| `gld_sales_summary` | 1 dòng / ngày | số đơn, số khách, doanh thu, giảm giá, đơn online/offline (**đếm theo đơn**), `avg_order_value` |
| `gld_customer_metrics` | 1 dòng / khách (kể cả chưa mua) | số đơn, doanh thu, `avg_order_value` **theo đơn**, lần mua đầu/cuối, `days_since_last_order` (so với ngày cuối của bộ dữ liệu, vì dữ liệu dừng ở 2014) |
| `gld_product_performance` | 1 dòng / sản phẩm (kể cả chưa bán) | số lượng, doanh thu, lợi nhuận, `profit_margin_pct` (NULL khi chưa có doanh thu → không chia cho 0) |
| `gld_customer_segments` | 1 dòng / khách đã mua | Điểm R/F/M (1–4, `NTILE(4)`), mã RFM, phân khúc: Champions, Loyal, Promising, Needs Attention, At Risk, Hibernating |

Gold là **table**; dbt-sqlserver tự tạo **clustered columnstore index** → truy vấn tổng hợp nhanh.

---

## Bước 6 — Tài liệu model

- **Mọi model và mọi cột** đều có `description` trong `_<tầng>__models.yml`. Đã kiểm tra tự động: 14/14 model, không cột nào thiếu mô tả.
- Mô tả dài dùng **doc block** trong `dbt/models/docs.md`, gọi bằng `"{{ doc('order_status') }}"`.
- `__overview__` thay trang chủ của tài liệu dbt.

Xem tài liệu ngay trên máy:

```bash
docker compose exec dbt dbt docs generate
cd dbt/target && python3 -m http.server 8081      # mở http://localhost:8081, Ctrl+C để dừng
cd ../..
```

Trang có sơ đồ **lineage** tương tác (biểu tượng ở góc dưới bên phải). File 10 sẽ đưa trang này lên GitHub Pages.

---

## Bước 7 — Kiểm thử

Chi tiết đầy đủ: [`docs/TESTING.md`](../docs/TESTING.md). Tóm tắt:

| Nhóm | Số lượng | Ví dụ |
|---|---|---|
| `not_null` | 50 | khóa chính, cột bắt buộc |
| `unique` | 26 | khóa chính, mã đơn, tên sản phẩm |
| `accepted_values` | 19 | `order_status` ∈ 1..6, `order_channel`, `customer_segment` |
| `relationships` | 11 | `slvr_sales_orders.customer_id` → `slvr_customers` |
| `positive_value` *(tự viết)* | 19 | số lượng, đơn giá, doanh thu |
| `date_not_before` *(tự viết)* | 5 | `ship_date ≥ order_date` |
| `row_count_greater_than` *(tự viết)* | 4 | mọi bảng gold > 100 dòng |
| `valid_date_range` *(tự viết)* | 2 | `order_date` từ 2011, không ở tương lai |
| `dbt_utils.*` | 4 | khóa ghép, `online + offline = total`, `profit_margin ≤ 100` |
| Singular *(nghiệp vụ)* | 3 | đối soát doanh thu và số đơn gold ↔ silver |
| **Tổng** | **143** | (gồm 14 test trên bảng nguồn) |

**Cách viết một generic test** (vd. `dbt/tests/generic/positive_value.sql`):

```sql
{% test positive_value(model, column_name, allow_zero=false) %}
select {{ column_name }} as invalid_value
from {{ model }}
where {{ column_name }} {{ '<' if allow_zero else '<=' }} 0
{% endtest %}
```

Test trả về **dòng nào** = dòng đó **vi phạm**. Dùng trong YAML: `- positive_value` hoặc `- positive_value: {allow_zero: true}`.

**Tương thích SQL Server (lỗi thật đã gặp khi chạy thử):** dbt-sqlserver bọc SQL của mỗi test trong `CREATE VIEW`. Test `dbt_utils.expression_is_true` gốc sinh ra `select 1 from ...` (cột không tên) → SQL Server báo lỗi 4511 *"Create View or Function failed because no column name was specified for column 1"*. Cách sửa: viết bản riêng `sqlserver__test_expression_is_true` (`select 1 as failed_row`) trong `dbt/macros/compat/` và khai báo trong `dbt_project.yml`:

```yaml
dispatch:
  - macro_namespace: dbt_utils
    search_order: ['dbt_sqlserver_project', 'dbt_utils']   # tìm bản của dự án trước
```

**Singular test** là một câu SELECT trong `dbt/tests/`, trả về dòng = lỗi. 3 singular test bật `store_failures`: dòng vi phạm được lưu vào schema `<env>_dbt_test__audit`.

---

## Bước 8 — Chạy thử trên máy

### 8.1. Tạo nhánh

```bash
git switch develop
git pull
git switch -c feature/dbt-medallion-refactor
```

### 8.2. Kiểm tra cú pháp

```bash
docker compose exec dbt dbt deps
docker compose exec dbt dbt parse                                 # không lỗi
docker compose exec dbt dbt -q ls --resource-type model | wc -l   # 14  (-q: chỉ in danh sách, không in log)
docker compose exec dbt dbt -q ls --resource-type test | wc -l    # 143
```

### 8.3. Build toàn bộ với `--full-refresh`

```bash
docker compose exec dbt dbt build --full-refresh
```

> ⚠️ **Bắt buộc `--full-refresh` lần đầu.** Database dev đang có bảng `slvr_sales_orders` **kiểu cũ** (không có cột `modified_at`). Không full refresh → model incremental đọc bảng cũ và lỗi `Invalid column name 'modified_at'`.

Mong đợi ở cuối output:

```
Done. PASS=157 WARN=0 ERROR=0 SKIP=0 TOTAL=157
```

(157 = 14 model + 143 test. Điều quan trọng là **`ERROR=0`**.)

### 8.4. Dọn view/bảng cũ

Model đổi tên (vd. `brnz_customers` → `brnz_customer`) nhưng view cũ vẫn nằm trong database:

```bash
docker compose exec dbt dbt run-operation drop_orphan_relations                       # xem trước
docker compose exec dbt dbt run-operation drop_orphan_relations --args '{dry_run: false}'
```

Lần xem trước liệt kê `dev_bronze.brnz_customers`, `brnz_example`, `brnz_products`, `brnz_sales_orders`.

```bash
docker compose exec dbt dbt run-operation health_check     # ✅ Health check OK
```

### 8.5. Diễn tập freshness

```bash
docker compose exec dbt dbt source freshness                  # chưa mô phỏng: ERROR STALE (dữ liệu 2014)
docker compose exec dbt dbt run-operation simulate_new_data   # ✅ Đã mô phỏng dữ liệu mới...
docker compose exec dbt dbt source freshness                  # PASS cả 7 bảng
```

> Nếu lần đầu đã PASS: trong 48 giờ qua bạn đã chạy `simulate_new_data` (hoặc CI/DAG đã chạy trên database này).

### 8.6. Diễn tập một test thất bại (để hiểu test hoạt động)

AdventureWorks có sẵn nhiều ràng buộc CHECK (vd. `OrderQty > 0`), nên không thể ghi số lượng âm để thử. Ta dùng một thay đổi **đảo ngược được**: lùi ngày đặt của một đơn hàng 10 năm (về 2001), vi phạm test `valid_date_range` (đơn hàng phải từ 2011).

```bash
# Lùi ngày đặt hàng của đơn 43659 đi 10 năm (tạm tắt trigger để không đụng dữ liệu khác)
docker compose exec -T sqlserver bash -c '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d AdventureWorks2014 -Q "ALTER TABLE Sales.SalesOrderHeader DISABLE TRIGGER ALL; UPDATE Sales.SalesOrderHeader SET OrderDate = DATEADD(year, -10, OrderDate) WHERE SalesOrderID = 43659; ALTER TABLE Sales.SalesOrderHeader ENABLE TRIGGER ALL;"'

docker compose exec dbt dbt test --select brnz_sales_order_header
# → ... FAIL 1 valid_date_range_brnz_sales_order_header_order_date__2011_01_01  [FAIL 1 in 0.02s]
# → Done. PASS=15 WARN=0 ERROR=1 SKIP=0 TOTAL=16

# Trả lại đúng ngày cũ (cộng lại 10 năm)
docker compose exec -T sqlserver bash -c '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d AdventureWorks2014 -Q "ALTER TABLE Sales.SalesOrderHeader DISABLE TRIGGER ALL; UPDATE Sales.SalesOrderHeader SET OrderDate = DATEADD(year, 10, OrderDate) WHERE SalesOrderID = 43659; ALTER TABLE Sales.SalesOrderHeader ENABLE TRIGGER ALL;"'
docker compose exec dbt dbt test --select brnz_sales_order_header     # Done. PASS=16 ... ERROR=0
```

> Chỉ chạy lệnh "lùi" **một lần** rồi lệnh "trả lại" **một lần**. Lỡ chạy lệnh lùi hai lần → chạy lệnh trả lại hai lần.

### 8.7. Xem kết quả bằng SQL

Trong VS Code (extension SQL Server), chạy:

```sql
SELECT TOP 10 * FROM dev_gold.gld_sales_summary ORDER BY order_date DESC;
SELECT customer_segment, COUNT(*) AS customers FROM dev_gold.gld_customer_segments GROUP BY customer_segment;
SELECT TOP 10 product_name, total_revenue, profit_margin_pct FROM dev_gold.gld_product_performance ORDER BY total_revenue DESC;
```

---

## Bước 9 — Đo hiệu năng

```bash
./scripts/benchmark_incremental.sh
```

Script chạy 3 trường hợp (full refresh; incremental không có dữ liệu mới; incremental sau khi mô phỏng 20 đơn hàng) và in bảng Markdown. [`docs/PERFORMANCE.md`](../docs/PERFORMANCE.md) **đã có số liệu đo trên máy bạn ngày 2026-11-13** (full refresh 1.15 s; incremental 0.19–0.28 s). Chạy lại script nếu muốn cập nhật, rồi thay bảng trong file.

---

## Bước 10 — Commit và Pull Request

### 10.1. Commit theo kế hoạch

```bash
# 1. Generic tests trước (YAML các tầng dùng chúng)
git add dbt/tests/generic/
git commit -m "test(dbt): add custom generic tests"

# 2. Doc blocks, cấu hình dự án, macro mô phỏng dữ liệu
git add dbt/models/docs.md dbt/dbt_project.yml dbt/macros/ops/simulate_new_data.sql dbt/macros/compat/
git commit -m "feat(dbt): add doc blocks, layer tags, SQL Server test compatibility and data simulation macro"

# 3. Bronze (gồm cả xóa file cũ). -A để Git ghi nhận cả file bị xóa trong thư mục này
git add -A dbt/models/bronze dbt/models/sources.yml
git commit -m "refactor(dbt): split bronze layer into one model per source table"

# 4. Silver
git add -A dbt/models/silver
git commit -m "feat(dbt): rebuild silver layer with business logic and incremental orders"

# 5. Gold
git add -A dbt/models/gold
git commit -m "fix(dbt): correct gold metrics and add RFM customer segments"

# 6. Singular tests
git add dbt/tests/assert_gold_revenue_matches_silver.sql dbt/tests/assert_customer_orders_match_silver.sql \
        dbt/tests/assert_every_buyer_has_segment.sql
git commit -m "test(dbt): add singular business reconciliation tests"

# 7. Tài liệu (sau khi đã điền số liệu ở Bước 9)
git add docs/TESTING.md docs/PERFORMANCE.md scripts/benchmark_incremental.sh
git commit -m "docs: add testing strategy and performance notes"

git status --short dbt/     # chỉ còn dbt/models/exposures.yml (thuộc file 10)
```

> `git add -A <thư mục>` chỉ áp dụng cho **thư mục đó**, an toàn. Đừng dùng `git add -A` không kèm đường dẫn.

### 10.2. Pull Request

```bash
git push -u origin feature/dbt-medallion-refactor
gh pr create --base develop \
  --title "refactor(dbt): rebuild medallion layers with full test coverage" \
  --body "Bronze 1-1 với nguồn, silver/gold viết lại và sửa lỗi logic, model RFM, 143 test, source freshness, tài liệu kiểm thử và hiệu năng."
gh pr checks --watch
```

Trên trang **Summary** của job `dbt-build`: `build` ≈ 157 thành công, 0 lỗi; bước *Source freshness* giờ đã chạy (không còn bị bỏ qua).

```bash
gh pr merge --squash --delete-branch
git switch develop && git pull
```

Merge → **Deploy dev** tự chạy với model mới.

---

## Checklist hoàn thành

- [ ] `dbt build --full-refresh` trên máy: `ERROR=0` (~157 node)
- [ ] Đã dọn view cũ (`drop_orphan_relations`), `health_check` OK
- [ ] Freshness: ERROR trước khi mô phỏng, PASS sau khi mô phỏng
- [ ] Đã diễn tập một test thất bại và khôi phục dữ liệu
- [ ] `docs/PERFORMANCE.md` đã có số liệu thật
- [ ] PR có 4 check xanh, đã merge; Deploy dev xanh

**Đối chiếu đề bài:**

| Yêu cầu | Đáp ứng |
|---|---|
| Bronze ≥ 3 bảng nguồn, làm sạch, freshness, mô tả mọi cột | 7 model, freshness 7 bảng, mô tả 100% cột |
| Silver ≥ 2 model, join nhiều bronze, logic nghiệp vụ, có test | 3 model |
| Gold ≥ 2 model, aggregation, tối ưu, sẵn sàng phân tích | 4 model, columnstore, incremental ở tầng dưới |
| `not_null`, `unique`, `relationships`, `accepted_values` | ✅ |
| ≥ 3 custom generic test, test logic nghiệp vụ | 4 generic + 3 singular |
| Freshness cho mọi nguồn, ngưỡng warn/error, độ trễ kỳ vọng | ✅ |
| Tài liệu test | `docs/TESTING.md` |

---

## Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `Invalid column name 'modified_at'` ở `slvr_sales_orders` | Bảng cũ còn trong database, chạy incremental | `dbt build --full-refresh --select slvr_sales_orders+` |
| `Compilation Error ... 'doc' ... not found` | Chưa có `docs.md` (thiếu file) | Kiểm tra `dbt/models/docs.md` tồn tại |
| `dbt found ... package(s) specified in packages.yml, but only 0 installed` | Chưa `dbt deps` | `docker compose exec dbt dbt deps` |
| Test `valid_date_range` hoặc test khác lỗi sau khi diễn tập | Chưa trả lại dữ liệu ở Bước 8.6 | Chạy lệnh "trả lại"; nếu không chắc, restore lại database: `docker compose down -v` → `docker compose up -d` → `./scripts/init_sqlserver.sh` |
| Test `accepted_values` lỗi ở `person_type` / `product_line` | Có giá trị mới ngoài danh sách | Xem giá trị: `SELECT DISTINCT ...`; cập nhật danh sách nếu hợp lệ |
| `drop_orphan_relations` liệt kê cả bảng `dbt_test__audit` | Không xảy ra: macro chỉ xét schema của 3 tầng | — |
| sqlfluff báo lỗi khi commit model | Format SQL chưa đúng | Hook `sqlfluff-fix` tự sửa → `git add` lại file, commit lại |
| `dbt-build` trên CI đỏ ở *Source freshness* | `simulate_new_data` lỗi quyền | `dbt_user` cần `db_owner` (do `init_sqlserver.sh` cấp) |

---

## Tiếp theo

→ **`05_AIRFLOW_DAG.md`**: DAG `dbt_pipeline` chạy theo tầng, retry, kiểm tra chất lượng, thông báo Discord (Phần 3, 15 điểm).
