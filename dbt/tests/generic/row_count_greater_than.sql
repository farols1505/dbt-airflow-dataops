{#-
    Generic test (cấp MODEL, không gắn với cột): bảng phải có NHIỀU HƠN min_rows dòng.
    Bắt lỗi "bảng rỗng" — ví dụ join sai khiến model build thành công nhưng không có dữ liệu.

    Cách dùng trong YAML (đặt ngay dưới tên model):
        data_tests:
          - row_count_greater_than:
              min_rows: 100
-#}
{% test row_count_greater_than(model, min_rows=0) %}

select count(*) as actual_rows
from {{ model }}
having count(*) <= {{ min_rows }}

{% endtest %}
