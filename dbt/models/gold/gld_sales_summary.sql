-- Gold: tổng hợp doanh số theo NGÀY.
-- Sửa lỗi so với bản gốc: online_orders / offline_orders đếm theo ĐƠN (distinct sales_order_id),
-- không đếm theo dòng sản phẩm.

with sales as (
    select * from {{ ref('slvr_sales_orders') }}
),

daily as (
    select
        order_date,
        count(distinct sales_order_id) as total_orders,
        count(distinct customer_id) as unique_customers,
        sum(order_qty) as total_items_sold,
        sum(line_total) as total_revenue,
        sum(discount_amount) as total_discount,
        count(distinct case when order_channel = 'Online' then sales_order_id end) as online_orders,
        count(distinct case when order_channel = 'Offline' then sales_order_id end) as offline_orders,
        sum(case when has_discount = 1 then line_total else 0 end) as discounted_revenue
    from sales
    group by order_date
)

select
    order_date,
    total_orders,
    unique_customers,
    total_items_sold,
    total_revenue,
    total_discount,
    online_orders,
    offline_orders,
    discounted_revenue,
    cast(total_revenue / nullif(total_orders, 0) as decimal(19, 4)) as avg_order_value
from daily
