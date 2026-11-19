-- Bronze: danh mục lớn của sản phẩm (1-1 với Production.ProductCategory).

with source as (
    select * from {{ source('production', 'ProductCategory') }}
),

renamed as (
    select
        cast(ProductCategoryID as int) as product_category_id,
        trim(Name) as category_name,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
