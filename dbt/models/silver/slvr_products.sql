-- Silver: sản phẩm = product + subcategory + category.
-- Logic nghiệp vụ: phân khúc giá, trạng thái còn bán, giá trị mặc định cho cột thiếu.

with products as (
    select * from {{ ref('brnz_product') }}
),

subcategories as (
    select * from {{ ref('brnz_product_subcategory') }}
),

categories as (
    select * from {{ ref('brnz_product_category') }}
),

joined as (
    select
        p.product_id,
        p.product_name,
        p.product_number,
        coalesce(p.color, 'N/A') as color,
        coalesce(p.size, 'N/A') as size,
        p.weight,
        p.weight_unit,
        p.standard_cost,
        p.list_price,
        p.product_line,
        p.product_class,
        p.product_style,
        p.make_flag,
        p.finished_goods_flag,
        p.product_subcategory_id as subcategory_id,
        coalesce(s.subcategory_name, 'Uncategorized') as subcategory_name,
        s.product_category_id as category_id,
        coalesce(c.category_name, 'Uncategorized') as category_name,
        case
            when p.list_price = 0 then 'Not for sale'
            when p.list_price < 100 then 'Budget'
            when p.list_price < 1000 then 'Mid-range'
            else 'Premium'
        end as price_tier,
        p.sell_start_date,
        p.sell_end_date,
        case
            when p.sell_end_date is null and p.discontinued_date is null then 1
            else 0
        end as is_active,
        p.modified_at
    from products as p
    left join subcategories as s
        on p.product_subcategory_id = s.product_subcategory_id
    left join categories as c
        on s.product_category_id = c.product_category_id
)

select * from joined
