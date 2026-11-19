{#- Các hàm nhỏ dùng chung cho macro vận hành (health check, backup, restore). -#}

{#- Tên schema của một tầng theo target hiện tại, vd. layer='gold', target=prod → 'prod_gold'. -#}
{% macro ops_layer_schema(layer) %}
    {{ return(target.schema ~ '_' ~ layer) }}
{% endmacro %}


{#- Danh sách tên bảng/view trong một schema. table_type: 'BASE TABLE', 'VIEW' hoặc none (cả hai). -#}
{% macro ops_list_relations(schema_name, table_type=none) %}
    {% set sql %}
        select table_name
        from information_schema.tables
        where table_schema = '{{ schema_name }}'
        {% if table_type %}and table_type = '{{ table_type }}'{% endif %}
        order by table_name
    {% endset %}
    {% set result = run_query(sql) %}
    {{ return(result.columns[0].values() | list) }}
{% endmacro %}


{#- Số dòng của một bảng/view. -#}
{% macro ops_row_count(schema_name, relation_name) %}
    {% set result = run_query('select count(*) from [' ~ schema_name ~ '].[' ~ relation_name ~ ']') %}
    {{ return(result.columns[0].values()[0] | int) }}
{% endmacro %}
