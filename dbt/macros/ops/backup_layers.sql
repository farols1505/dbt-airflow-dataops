{#-
    BACKUP trước khi deploy: sao chép mọi BẢNG của từng tầng sang schema backup.
        prod_gold.gld_sales_summary  →  prod_gold__backup.gld_sales_summary

    Chỉ sao lưu bảng (silver, gold). Bronze là view, được tạo lại từ code nên không cần sao lưu.
    Backup cũ bị xóa trước khi tạo backup mới (luôn chỉ giữ 1 bản: bản ngay trước lần deploy).

    Cách chạy:
        dbt run-operation backup_layers --target prod
        dbt run-operation backup_layers --args '{layers: [gold]}'
-#}
{% macro backup_layers(layers=['silver', 'gold']) %}

    {% for layer in layers %}
        {% set source_schema = ops_layer_schema(layer) %}
        {% set backup_schema = source_schema ~ '__backup' %}

        {% do run_query("if schema_id('" ~ backup_schema ~ "') is null exec('create schema [" ~ backup_schema ~ "]')") %}

        {# Xóa backup cũ #}
        {% for old_table in ops_list_relations(backup_schema, 'BASE TABLE') %}
            {% do run_query('drop table [' ~ backup_schema ~ '].[' ~ old_table ~ ']') %}
        {% endfor %}

        {% set tables = ops_list_relations(source_schema, 'BASE TABLE') %}
        {% for table_name in tables %}
            {% do run_query('select * into [' ~ backup_schema ~ '].[' ~ table_name ~ '] from [' ~ source_schema ~ '].[' ~ table_name ~ ']') %}
            {{ log('   💾 ' ~ source_schema ~ '.' ~ table_name ~ ' → ' ~ backup_schema ~ '.' ~ table_name, info=True) }}
        {% endfor %}

        {{ log('✅ Backup tầng ' ~ layer ~ ': ' ~ tables | length ~ ' bảng.', info=True) }}
    {% endfor %}

{% endmacro %}
