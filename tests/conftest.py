"""Cấu hình chung cho pytest: cho phép import code trong airflow/dags (vd. dataops_utils).

Airflow tự thêm thư mục dags vào sys.path khi chạy thật; khi chạy pytest ta phải tự thêm.
"""

import os
import sys

# Mặc định: <repo>/airflow/dags. Đặt biến DAG_TESTS_DAGS_FOLDER để chạy test với thư mục khác
# (vd. chạy bên trong container Airflow: DAG_TESTS_DAGS_FOLDER=/opt/airflow/dags).
DAGS_FOLDER = os.path.abspath(
    os.environ.get("DAG_TESTS_DAGS_FOLDER")
    or os.path.join(os.path.dirname(__file__), "..", "airflow", "dags")
)

os.environ.setdefault("AIRFLOW__CORE__LOAD_EXAMPLES", "False")
os.environ.setdefault("AIRFLOW__CORE__DAGS_FOLDER", DAGS_FOLDER)

if DAGS_FOLDER not in sys.path:
    sys.path.insert(0, DAGS_FOLDER)
