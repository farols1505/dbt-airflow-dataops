{#-
    Dọn bảng/view "mồ côi": có trong schema của tầng nhưng KHÔNG còn model dbt nào tương ứng
    (vd. sau khi đổi tên brnz_customers → brnz_customer, view cũ vẫn nằm lại trong database).

    Mặc định chỉ LIỆT KÊ (dry_run=true). Xóa thật: truyền dry_run: false.

    Cách chạy:
        dbt run-operation drop_orphan_relations                         # xem trước
        dbt run-operation drop_orphan_relations --args '{dry_run: false}'
-#}
{% macro drop_orphan_relations(layers=['bronze', 'silver', 'gold'], dry_run=true) %}

    {% set expected = [] %}
    {% for node in graph.nodes.values() if node.resource_type == 'model' %}
        {% do expected.append((node.schema ~ '.' ~ node.alias) | lower) %}
    {% endfor %}

    {% set orphans = [] %}
    {% for layer in layers %}
        {% set schema_name = ops_layer_schema(layer) %}
        {% for kind in ['VIEW', 'BASE TABLE'] %}
            {% for relation_name in ops_list_relations(schema_name, kind) %}
                {% if (schema_name ~ '.' ~ relation_name) | lower not in expected %}
                    {% do orphans.append((schema_name, relation_name, kind)) %}
                {% endif %}
            {% endfor %}
        {% endfor %}
    {% endfor %}

    {% if orphans | length == 0 %}
        {{ log('✅ Không có bảng/view mồ côi.', info=True) }}
    {% endif %}

    {% for schema_name, relation_name, kind in orphans %}
        {% set object_type = 'view' if kind == 'VIEW' else 'table' %}
        {% if dry_run %}
            {{ log('   (dry run) sẽ xóa ' ~ object_type ~ ' ' ~ schema_name ~ '.' ~ relation_name, info=True) }}
        {% else %}
            {% do run_query('drop ' ~ object_type ~ ' if exists [' ~ schema_name ~ '].[' ~ relation_name ~ ']') %}
            {{ log('   🗑️  Đã xóa ' ~ object_type ~ ' ' ~ schema_name ~ '.' ~ relation_name, info=True) }}
        {% endif %}
    {% endfor %}

    {% if dry_run and orphans | length > 0 %}
        {{ log('ℹ️  Chạy lại với --args "{dry_run: false}" để xóa thật.', info=True) }}
    {% endif %}

{% endmacro %}
