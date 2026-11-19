{#-
    HEALTH CHECK sau deploy: mọi bảng/view trong schema của từng tầng phải TỒN TẠI và CÓ DỮ LIỆU.

    Không liệt kê tên bảng cố định (quyết định D11): đổi tên/thêm model không phải sửa macro này.
    Lỗi → raise_compiler_error → lệnh dbt trả mã lỗi ≠ 0 → bước deploy trên GitHub Actions báo đỏ.

    Cách chạy:
        dbt run-operation health_check --target prod
        dbt run-operation health_check --args '{layers: [gold], min_rows: 10}'
-#}
{% macro health_check(layers=['bronze', 'silver', 'gold'], min_rows=1) %}

    {% set problems = [] %}
    {% set checked = [] %}

    {% for layer in layers %}
        {% set schema_name = ops_layer_schema(layer) %}
        {% set relations = ops_list_relations(schema_name) %}

        {% if relations | length == 0 %}
            {% do problems.append('Schema ' ~ schema_name ~ ' không có bảng/view nào') %}
        {% endif %}

        {% for relation_name in relations %}
            {% set row_count = ops_row_count(schema_name, relation_name) %}
            {% do checked.append(1) %}
            {{ log('   ' ~ schema_name ~ '.' ~ relation_name ~ ': ' ~ row_count ~ ' dòng', info=True) }}
            {% if row_count < min_rows %}
                {% do problems.append(schema_name ~ '.' ~ relation_name ~ ' chỉ có ' ~ row_count ~ ' dòng (cần >= ' ~ min_rows ~ ')') %}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {% if problems %}
        {{ exceptions.raise_compiler_error('❌ Health check THẤT BẠI:\n - ' ~ problems | join('\n - ')) }}
    {% endif %}

    {{ log('✅ Health check OK: ' ~ checked | length ~ ' bảng/view ở các tầng ' ~ layers | join(', ') ~ ' đều có dữ liệu.', info=True) }}

{% endmacro %}
