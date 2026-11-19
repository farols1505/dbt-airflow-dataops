-- Singular test (logic nghiệp vụ): mọi khách hàng đã từng mua (has_ordered = 1)
-- phải được xếp vào đúng một phân khúc RFM.

{{ config(store_failures=true) }}

select m.customer_id
from {{ ref('gld_customer_metrics') }} as m
left join {{ ref('gld_customer_segments') }} as s
    on m.customer_id = s.customer_id
where
    m.has_ordered = 1
    and s.customer_id is null
