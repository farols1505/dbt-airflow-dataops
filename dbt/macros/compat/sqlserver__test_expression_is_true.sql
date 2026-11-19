{#-
    Bản SQL Server của test dbt_utils.expression_is_true.

    Vì sao cần? dbt-sqlserver bọc câu SQL của mỗi test trong một CREATE VIEW. Bản gốc của
    dbt_utils sinh ra "select 1 from ..." (cột không có tên) → SQL Server báo lỗi 4511
    "Create View or Function failed because no column name was specified for column 1".
    Bản này đặt tên cho cột: "select 1 as failed_row".

    dbt dùng macro này thay bản gốc nhờ cấu hình dispatch trong dbt_project.yml
    (search_order: dự án này trước, dbt_utils sau).
-#}
{% macro sqlserver__test_expression_is_true(model, expression, column_name) %}

{% set column_list = '*' if should_store_failures() else "1 as failed_row" %}

select
    {{ column_list }}
from {{ model }}
{% if column_name is none %}
where not({{ expression }})
{%- else %}
where not({{ column_name }} {{ expression }})
{%- endif %}

{% endmacro %}
