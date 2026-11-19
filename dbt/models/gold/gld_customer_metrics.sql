-- Gold: chỉ số theo KHÁCH HÀNG (1 dòng / 1 khách hàng, kể cả khách chưa mua).
-- Sửa lỗi so với bản gốc:
--   * avg_order_value = tổng doanh thu / số ĐƠN (bản gốc lấy trung bình từng DÒNG sản phẩm).
--   * orders_with_discount đếm theo ĐƠN có giảm giá (bản gốc đếm theo dòng).
-- days_since_last_order tính so với ngày đặt hàng mới nhất của bộ dữ liệu
-- (dữ liệu AdventureWorks kết thúc năm 2014, so với hôm nay sẽ vô nghĩa).

with customers as (
    select * from {{ ref('slvr_customers') }}
),

sales as (
    select * from {{ ref('slvr_sales_orders') }}
),

dataset_end as (
    select max(order_date) as max_order_date
    from sales
),

customer_sales as (
    select
        customer_id,
        count(distinct sales_order_id) as total_orders,
        sum(line_total) as total_revenue,
        sum(order_qty) as total_items_purchased,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        count(distinct case when has_discount = 1 then sales_order_id end) as orders_with_discount
    from sales
    group by customer_id
)

select
    c.customer_id,
    c.full_name,
    c.customer_type,
    c.territory_id,
    case
        when s.customer_id is null then 0
        else 1
    end as has_ordered,
    coalesce(s.total_orders, 0) as total_orders,
    coalesce(s.total_revenue, 0) as total_revenue,
    cast(coalesce(s.total_revenue / nullif(s.total_orders, 0), 0) as decimal(19, 4)) as avg_order_value,
    coalesce(s.total_items_purchased, 0) as total_items_purchased,
    coalesce(s.orders_with_discount, 0) as orders_with_discount,
    s.first_order_date,
    s.last_order_date,
    datediff(day, s.last_order_date, d.max_order_date) as days_since_last_order
from customers as c
left join customer_sales as s
    on c.customer_id = s.customer_id
cross join dataset_end as d
