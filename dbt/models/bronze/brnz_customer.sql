-- Bronze: khách hàng (1-1 với Sales.Customer).

with source as (
    select * from {{ source('sales', 'Customer') }}
),

renamed as (
    select
        cast(CustomerID as int) as customer_id,
        cast(PersonID as int) as person_id,
        cast(StoreID as int) as store_id,
        cast(TerritoryID as int) as territory_id,
        trim(AccountNumber) as account_number,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
