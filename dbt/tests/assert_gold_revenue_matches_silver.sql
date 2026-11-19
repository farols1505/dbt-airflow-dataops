-- Singular test (đối soát nghiệp vụ): tổng doanh thu ở gold (theo ngày) phải bằng
-- tổng thành tiền ở silver. Lệch → logic tổng hợp ở gold bị sai (mất dòng hoặc nhân đôi dòng).
-- Test trả về dòng nào = lỗi.

{{ config(store_failures=true) }}

with gold as (
    select sum(total_revenue) as revenue
    from {{ ref('gld_sales_summary') }}
),

silver as (
    select sum(line_total) as revenue
    from {{ ref('slvr_sales_orders') }}
)

select
    gold.revenue as gold_revenue,
    silver.revenue as silver_revenue
from gold
cross join silver
where abs(gold.revenue - silver.revenue) > 0.01
