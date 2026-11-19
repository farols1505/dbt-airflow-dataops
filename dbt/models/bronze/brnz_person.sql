-- Bronze: người (1-1 với Person.Person). Bỏ các cột XML (AdditionalContactInfo, Demographics) và rowguid.

with source as (
    select * from {{ source('person', 'Person') }}
),

renamed as (
    select
        cast(BusinessEntityID as int) as person_id,
        trim(PersonType) as person_type,
        nullif(trim(Title), '') as title,
        trim(FirstName) as first_name,
        nullif(trim(MiddleName), '') as middle_name,
        trim(LastName) as last_name,
        nullif(trim(Suffix), '') as suffix,
        cast(EmailPromotion as int) as email_promotion,
        cast(ModifiedDate as datetime2) as modified_at
    from source
)

select * from renamed
