{#-
    RESTORE (rollback dữ liệu): khôi phục mọi bảng của từng tầng từ schema backup
    (do backup_layers tạo trước lần deploy).

    - Bảng có trong backup  → xóa bản hiện tại, chép lại từ backup.
    - Bảng KHÔNG có trong backup (do lần deploy lỗi tạo thêm) → xóa đi.
    Không có backup → báo lỗi, không làm gì (an toàn).

    Cách chạy:
        dbt run-operation restore_layers --target prod
-#}
{% macro restore_layers(layers=['silver', 'gold']) %}

    {% for layer in layers %}
        {% set target_schema = ops_layer_schema(layer) %}
        {% set backup_schema = target_schema ~ '__backup' %}
        {% set backup_tables = ops_list_relations(backup_schema, 'BASE TABLE') %}

        {% if backup_tables | length == 0 %}
            {{ exceptions.raise_compiler_error('❌ Không có backup cho ' ~ target_schema ~ ' (schema ' ~ backup_schema ~ ' trống). Không thể restore.') }}
        {% endif %}

        {% for table_name in ops_list_relations(target_schema, 'BASE TABLE') %}
            {% if table_name not in backup_tables %}
                {% do run_query('drop table [' ~ target_schema ~ '].[' ~ table_name ~ ']') %}
                {{ log('   🗑️  Xóa bảng mới không có trong backup: ' ~ target_schema ~ '.' ~ table_name, info=True) }}
            {% endif %}
        {% endfor %}

        {% for table_name in backup_tables %}
            {% do run_query('drop table if exists [' ~ target_schema ~ '].[' ~ table_name ~ ']') %}
            {% do run_query('select * into [' ~ target_schema ~ '].[' ~ table_name ~ '] from [' ~ backup_schema ~ '].[' ~ table_name ~ ']') %}
            {{ log('   ♻️  ' ~ backup_schema ~ '.' ~ table_name ~ ' → ' ~ target_schema ~ '.' ~ table_name, info=True) }}
        {% endfor %}

        {{ log('✅ Restore tầng ' ~ layer ~ ': ' ~ backup_tables | length ~ ' bảng.', info=True) }}
    {% endfor %}

{% endmacro %}
