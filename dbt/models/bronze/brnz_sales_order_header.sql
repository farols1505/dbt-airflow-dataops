-- Bronze: header đơn hàng (1-1 với Sales.SalesOrderHeader).
-- Chỉ đổi tên cột sang snake_case, ép kiểu, làm sạch chuỗi. KHÔNG join, KHÔNG logic nghiệp vụ.

with source as (
    select * from {{ source('sales', 'SalesOrderHeader') }}
),

renamed as (
    select
        cast(SalesOrderID as int) as sales_order_id,
        cast(RevisionNumber as int) as revision_number,
        cast(OrderDate as date) as order_date,
        cast(DueDate as date) as due_date,
        cast(ShipDate as date) as ship_date,
        cast(Status as int) as order_status,
        cast(OnlineOrderFlag as int) as online_order_flag,
        trim(SalesOrderNumber) as sales_order_number,
        nullif(trim(PurchaseOrderNumber), '') as purchase_order_number,
        cast(CustomerID as int) as customer_id,
        cast(SalesPersonID as int) as sales_person_id,
        cast(TerritoryID as int) as territory_id,
        cast(SubTotal as decimal(19, 4)) as sub_total,
        cast(TaxAmt as decimal(19, 4)) as tax_amount,
        cast(Freight as decimal(19, 4)) as freight,
        cast(TotalDue as decimal(19, 4)) as total_due,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
