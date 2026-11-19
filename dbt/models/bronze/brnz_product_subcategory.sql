-- Bronze: danh mục con của sản phẩm (1-1 với Production.ProductSubcategory).

with source as (
    select * from {{ source('production', 'ProductSubcategory') }}
),

renamed as (
    select
        cast(ProductSubcategoryID as int) as product_subcategory_id,
        cast(ProductCategoryID as int) as product_category_id,
        trim(Name) as subcategory_name,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
