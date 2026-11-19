-- Singular test (đối soát nghiệp vụ): tổng số đơn của mọi khách hàng ở gold phải bằng
-- số đơn hàng khác nhau ở silver (mỗi đơn thuộc đúng một khách hàng).

{{ config(store_failures=true) }}

with gold as (
    select sum(total_orders) as orders
    from {{ ref('gld_customer_metrics') }}
),

silver as (
    select count(distinct sales_order_id) as orders
    from {{ ref('slvr_sales_orders') }}
)

select
    gold.orders as gold_orders,
    silver.orders as silver_orders
from gold
cross join silver
where gold.orders <> silver.orders
