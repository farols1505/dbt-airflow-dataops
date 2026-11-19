{#-
    Generic test: ngày ở cột này KHÔNG được trước ngày ở cột compare_column (cùng một dòng).
    Ví dụ: ngày giao hàng không được trước ngày đặt hàng.
    Dòng có NULL ở một trong hai cột được bỏ qua.

    Cách dùng trong YAML (đặt dưới cột ship_date):
        data_tests:
          - date_not_before:
              compare_column: order_date
-#}
{% test date_not_before(model, column_name, compare_column) %}

select
    {{ column_name }} as checked_date,
    {{ compare_column }} as compare_date
from {{ model }}
where {{ column_name }} < {{ compare_column }}

{% endtest %}
