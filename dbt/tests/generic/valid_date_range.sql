{#-
    Generic test: ngày phải nằm trong khoảng [min_date, max_date].
    Không truyền max_date → mặc định là thời điểm hiện tại (chặn ngày ở tương lai).
    Giá trị NULL được bỏ qua.

    Cách dùng trong YAML:
        data_tests:
          - valid_date_range:
              min_date: "2011-01-01"
              max_date: "2030-12-31"       # tùy chọn
-#}
{% test valid_date_range(model, column_name, min_date, max_date=none) %}

select {{ column_name }} as invalid_date
from {{ model }}
where
    {{ column_name }} < cast('{{ min_date }}' as date)
    or {{ column_name }} > {% if max_date %}cast('{{ max_date }}' as date){% else %}getdate(){% endif %}

{% endtest %}
