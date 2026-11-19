-- Silver: dòng đơn hàng = order detail + order header (mức chi tiết: 1 dòng / 1 sản phẩm trong đơn).
--
-- Tối ưu hiệu năng (bảng lớn nhất, ~121 nghìn dòng):
--   * incremental: lần chạy sau chỉ xử lý các dòng có modified_at mới hơn dữ liệu đã có.
--     Chạy lại toàn bộ khi cần: dbt build --full-refresh --select slvr_sales_orders
--   * delete+insert theo order_detail_id: dòng cũ được xóa rồi chèn lại bản mới (không trùng lặp).
--   * dbt-sqlserver tự tạo clustered columnstore index (tốt cho truy vấn tổng hợp ở gold);
--     thêm index thường cho các cột hay dùng để join/lọc theo từng khách hàng, sản phẩm.

{{
    config(
        materialized='incremental',
        unique_key='order_detail_id',
        incremental_strategy='delete+insert',
        post_hook=[
            "{{ create_nonclustered_index(columns=['customer_id']) }}",
            "{{ create_nonclustered_index(columns=['product_id']) }}"
        ]
    )
}}

with headers as (
    select * from {{ ref('brnz_sales_order_header') }}
),

details as (
    select * from {{ ref('brnz_sales_order_detail') }}
),

joined as (
    select
        h.sales_order_id,
        d.order_detail_id,
        h.sales_order_number,
        h.order_date,
        h.due_date,
        h.ship_date,
        h.order_status,
        case h.order_status
            when 1 then 'In process'
            when 2 then 'Approved'
            when 3 then 'Backordered'
            when 4 then 'Rejected'
            when 5 then 'Shipped'
            when 6 then 'Cancelled'
        end as order_status_name,
        case
            when h.online_order_flag = 1 then 'Online'
            else 'Offline'
        end as order_channel,
        h.customer_id,
        h.sales_person_id,
        h.territory_id,
        d.product_id,
        d.special_offer_id,
        d.order_qty,
        d.unit_price,
        d.unit_price_discount,
        d.line_total,
        d.unit_price * d.order_qty as gross_amount,
        d.unit_price * d.order_qty - d.line_total as discount_amount,
        case
            when d.unit_price_discount > 0 then 1
            else 0
        end as has_discount,
        datediff(day, h.order_date, h.ship_date) as days_to_ship,
        case
            when d.modified_at > h.modified_at then d.modified_at
            else h.modified_at
        end as modified_at
    from details as d
    inner join headers as h
        on d.sales_order_id = h.sales_order_id
    where
        d.order_qty > 0
        and d.unit_price >= 0
)

select joined.* from joined
{% if is_incremental() %}
    -- Chỉ lấy các dòng thay đổi sau lần chạy trước
    where joined.modified_at > (select max(existing.modified_at) from {{ this }} as existing)
{% endif %}
