-- Gold: phân khúc khách hàng theo mô hình RFM (chỉ khách đã từng mua).
--   R (Recency)   : mua gần đây hay đã lâu       → điểm 1 (lâu nhất) .. 4 (gần nhất)
--   F (Frequency) : mua bao nhiêu đơn             → điểm 1 (ít nhất)  .. 4 (nhiều nhất)
--   M (Monetary)  : chi tiêu bao nhiêu            → điểm 1 (ít nhất)  .. 4 (nhiều nhất)
-- Điểm chia theo tứ phân vị (NTILE(4)); customer_id dùng để phân định khi bằng nhau → kết quả ổn định.

with metrics as (
    select * from {{ ref('gld_customer_metrics') }}
    where has_ordered = 1
),

scored as (
    select
        customer_id,
        full_name,
        customer_type,
        days_since_last_order as recency_days,
        total_orders as frequency,
        total_revenue as monetary,
        ntile(4) over (order by days_since_last_order desc, customer_id asc) as r_score,
        ntile(4) over (order by total_orders asc, customer_id asc) as f_score,
        ntile(4) over (order by total_revenue asc, customer_id asc) as m_score
    from metrics
)

select
    customer_id,
    full_name,
    customer_type,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    concat(r_score, f_score, m_score) as rfm_code,
    case
        when r_score >= 3 and f_score >= 3 and m_score >= 3 then 'Champions'
        when r_score >= 3 and f_score >= 2 then 'Loyal'
        when r_score >= 3 then 'Promising'
        when r_score = 2 then 'Needs Attention'
        when f_score >= 3 or m_score >= 3 then 'At Risk'
        else 'Hibernating'
    end as customer_segment
from scored
