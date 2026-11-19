-- Bronze: dòng chi tiết đơn hàng (1-1 với Sales.SalesOrderDetail).

with source as (
    select * from {{ source('sales', 'SalesOrderDetail') }}
),

renamed as (
    select
        cast(SalesOrderID as int) as sales_order_id,
        cast(SalesOrderDetailID as int) as order_detail_id,
        nullif(trim(CarrierTrackingNumber), '') as carrier_tracking_number,
        cast(OrderQty as int) as order_qty,
        cast(ProductID as int) as product_id,
        cast(SpecialOfferID as int) as special_offer_id,
        cast(UnitPrice as decimal(19, 4)) as unit_price,
        cast(UnitPriceDiscount as decimal(19, 4)) as unit_price_discount,
        cast(LineTotal as decimal(19, 4)) as line_total,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
