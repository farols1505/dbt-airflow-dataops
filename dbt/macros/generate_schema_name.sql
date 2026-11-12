{#
    Đặt tên schema = <schema của target>_<tên tầng>, ví dụ: dev_bronze, prod_gold.

    Vì sao cần file này? Adapter dbt-sqlserver 1.8 (kế thừa dbt-fabric) ghi đè cách
    đặt tên mặc định của dbt và chỉ dùng tên tầng (bronze/silver/gold), bỏ qua target.
    Khi đó dev, staging và prod sẽ ghi CHUNG vào một schema → không tách được môi trường.
    Macro này khôi phục hành vi chuẩn của dbt.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
