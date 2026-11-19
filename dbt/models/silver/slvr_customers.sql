-- Silver: khách hàng = customer + person.
-- Logic nghiệp vụ: phân loại khách cá nhân / cửa hàng, tạo tên hiển thị.

with customers as (
    select * from {{ ref('brnz_customer') }}
),

persons as (
    select * from {{ ref('brnz_person') }}
),

joined as (
    select
        c.customer_id,
        c.person_id,
        c.store_id,
        c.territory_id,
        c.account_number,
        p.first_name,
        p.last_name,
        case
            when p.person_id is not null then concat(p.first_name, ' ', p.last_name)
            else concat('Store #', c.store_id)
        end as full_name,
        case
            when c.store_id is null then 'Individual'
            else 'Store'
        end as customer_type,
        coalesce(p.email_promotion, 0) as email_promotion,
        case
            when p.modified_at > c.modified_at then p.modified_at
            else c.modified_at
        end as modified_at
    from customers as c
    left join persons as p
        on c.person_id = p.person_id
)

select * from joined
