-- Gold: hiệu quả kinh doanh theo SẢN PHẨM (1 dòng / 1 sản phẩm, kể cả sản phẩm chưa bán).
-- profit_margin_pct = NULL khi sản phẩm chưa có doanh thu (tránh chia cho 0).

with products as (
    select * from {{ ref('slvr_products') }}
),

sales as (
    select * from {{ ref('slvr_sales_orders') }}
),

product_sales as (
    select
        product_id,
        count(distinct sales_order_id) as total_orders,
        sum(order_qty) as total_quantity_sold,
        sum(line_total) as total_revenue,
        avg(unit_price) as avg_selling_price
    from sales
    group by product_id
)

select
    p.product_id,
    p.product_name,
    p.category_name,
    p.subcategory_name,
    p.color,
    p.price_tier,
    p.is_active,
    p.list_price,
    p.standard_cost,
    coalesce(s.total_orders, 0) as total_orders,
    coalesce(s.total_quantity_sold, 0) as total_quantity_sold,
    coalesce(s.total_revenue, 0) as total_revenue,
    s.avg_selling_price,
    coalesce(s.total_revenue, 0) - coalesce(s.total_quantity_sold, 0) * p.standard_cost as total_profit,
    case
        when coalesce(s.total_revenue, 0) > 0
            then cast(
                (s.total_revenue - s.total_quantity_sold * p.standard_cost) / s.total_revenue * 100
                as decimal(9, 2)
            )
    end as profit_margin_pct
from products as p
left join product_sales as s
    on p.product_id = s.product_id
