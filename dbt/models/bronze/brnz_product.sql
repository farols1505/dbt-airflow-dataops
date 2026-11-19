-- Bronze: sản phẩm (1-1 với Production.Product).
-- Các cột nchar(2) như ProductLine ('R ') được trim để bỏ khoảng trắng thừa.

with source as (
    select * from {{ source('production', 'Product') }}
),

renamed as (
    select
        cast(ProductID as int) as product_id,
        trim(Name) as product_name,
        trim(ProductNumber) as product_number,
        cast(MakeFlag as int) as make_flag,
        cast(FinishedGoodsFlag as int) as finished_goods_flag,
        nullif(trim(Color), '') as color,
        cast(SafetyStockLevel as int) as safety_stock_level,
        cast(ReorderPoint as int) as reorder_point,
        cast(StandardCost as decimal(19, 4)) as standard_cost,
        cast(ListPrice as decimal(19, 4)) as list_price,
        nullif(trim(Size), '') as size,
        cast(Weight as decimal(10, 2)) as weight,
        nullif(trim(WeightUnitMeasureCode), '') as weight_unit,
        cast(DaysToManufacture as int) as days_to_manufacture,
        nullif(trim(ProductLine), '') as product_line,
        nullif(trim(Class), '') as product_class,
        nullif(trim(Style), '') as product_style,
        cast(ProductSubcategoryID as int) as product_subcategory_id,
        cast(ProductModelID as int) as product_model_id,
        cast(SellStartDate as date) as sell_start_date,
        cast(SellEndDate as date) as sell_end_date,
        cast(DiscontinuedDate as date) as discontinued_date,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
