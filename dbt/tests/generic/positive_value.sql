{#-
    Generic test: giá trị của cột phải DƯƠNG (> 0).
    allow_zero=true → chấp nhận cả 0 (>= 0). Giá trị NULL được bỏ qua (dùng not_null nếu cần).

    Cách dùng trong YAML:
        data_tests:
          - positive_value                 # > 0
          - positive_value:
              allow_zero: true             # >= 0
-#}
{% test positive_value(model, column_name, allow_zero=false) %}

select {{ column_name }} as invalid_value
from {{ model }}
where {{ column_name }} {{ '<' if allow_zero else '<=' }} 0

{% endtest %}
