# Kiến trúc hệ thống

![Kiến trúc](images/architecture.svg)

## 1. Thành phần

| Thành phần | Container / nơi chạy | Vai trò |
|---|---|---|
| **SQL Server 2019** | `sqlserver` (:1433) | Chứa dữ liệu nguồn AdventureWorks2014 **và** kết quả biến đổi (các schema `<env>_bronze/silver/gold`) |
| **dbt** | `dbt` | Biến đổi dữ liệu bằng SQL + Jinja; chạy test; sinh tài liệu |
| **Airflow** | `airflow-webserver` (:8080), `airflow-scheduler` | Lập lịch và điều phối dbt (`docker exec` vào container dbt) |
| **PostgreSQL** | `postgres` | Metadata của Airflow (lịch sử DAG run, task instance) |
| **Grafana** *(tùy chọn)* | `grafana` (:3000) | Dashboard giám sát, đọc PostgreSQL + SQL Server |
| **GitHub Actions** | Máy ảo của GitHub | CI cho Pull Request; CD tới dev/staging/production; báo cáo; GitHub Pages |
| **Discord** | Dịch vụ ngoài | Nhận thông báo từ Airflow và GitHub Actions |

## 2. Luồng dữ liệu (medallion)

```mermaid
flowchart LR
  subgraph src["AdventureWorks2014"]
    S1[Sales.SalesOrderHeader]
    S2[Sales.SalesOrderDetail]
    S3[Sales.Customer]
    S4[Person.Person]
    S5[Production.Product]
    S6[Production.ProductSubcategory]
    S7[Production.ProductCategory]
  end
  subgraph bronze["bronze — 7 view"]
    B1[brnz_sales_order_header]
    B2[brnz_sales_order_detail]
    B3[brnz_customer]
    B4[brnz_person]
    B5[brnz_product]
    B6[brnz_product_subcategory]
    B7[brnz_product_category]
  end
  subgraph silver["silver — 3 bảng"]
    SV1[slvr_sales_orders<br/>incremental]
    SV2[slvr_customers]
    SV3[slvr_products]
  end
  subgraph gold["gold — 4 bảng"]
    G1[gld_sales_summary]
    G2[gld_customer_metrics]
    G3[gld_product_performance]
    G4[gld_customer_segments]
  end
  S1-->B1; S2-->B2; S3-->B3; S4-->B4; S5-->B5; S6-->B6; S7-->B7
  B1-->SV1; B2-->SV1; B3-->SV2; B4-->SV2; B5-->SV3; B6-->SV3; B7-->SV3
  SV1-->G1; SV1-->G2; SV2-->G2; SV1-->G3; SV3-->G3; G2-->G4
```

| Tầng | Quy tắc | Materialization |
|---|---|---|
| **Bronze** | 1 model / 1 bảng nguồn. Đổi tên cột sang `snake_case`, ép kiểu, `trim` chuỗi, bỏ cột XML/rowguid. **Không join, không logic nghiệp vụ** | `view` |
| **Silver** | Join nhiều bronze, logic nghiệp vụ (loại khách hàng, phân khúc giá, kênh bán, trạng thái đơn) | `table`; `slvr_sales_orders` là `incremental` |
| **Gold** | Tổng hợp phục vụ báo cáo: theo ngày, theo khách hàng, theo sản phẩm, phân khúc RFM | `table` |

Lineage đầy đủ (kèm exposures): [`LINEAGE.md`](LINEAGE.md) và https://farols1505.github.io/dbt-airflow-dataops/

## 3. Luồng điều phối (Airflow)

```mermaid
flowchart LR
  A[check_sqlserver] --> B[dbt_deps] --> C[simulate_ingestion] --> D[source_freshness]
  D --> E1[bronze.dbt_run] --> E2[bronze.dbt_test]
  E2 --> F1[silver.dbt_run] --> F2[silver.dbt_test]
  F2 --> G1[gold.dbt_run] --> G2[gold.dbt_test]
  G2 --> Q[data_quality<br/>business tests + SQL checks] --> H[dbt_docs_generate]
```

## 4. Luồng CI/CD

```mermaid
flowchart LR
  F[feature/*] -- PR --> CI{CI + PR validation}
  CI -- xanh, merge --> DEV[develop] --> D1[Deploy dev]
  DEV -- PR phát hành --> MAIN[main] --> D2[Deploy staging] --> AP{Duyệt} --> D3[Deploy production] --> T[tag prod-*]
  D3 -. lỗi .-> RB[Rollback tự động]
```

## 5. Quyết định kỹ thuật chính

| # | Quyết định | Lý do |
|---|---|---|
| 1 | Môi trường = **schema riêng** (`dev_*`, `staging_*`, `prod_*`) trong cùng database | Không cần thêm server; dbt chuyển môi trường chỉ bằng `--target` |
| 2 | Macro `generate_schema_name` riêng | Adapter dbt-sqlserver mặc định bỏ qua tiền tố target → mọi môi trường ghi chung một schema |
| 3 | CI/CD dựng **SQL Server tạm bằng chính docker-compose.yml** | Máy ảo GitHub không truy cập được máy local; chạy giống hệt local |
| 4 | Mật khẩu qua biến môi trường (`.env`, GitHub Secrets); biến `DBT_ENV_SECRET_*` | Repo public; dbt tự che giá trị `DBT_ENV_SECRET_*` trong log |
| 5 | Airflow gọi dbt bằng `docker exec`, chọn model theo **thư mục** (`path:models/<tầng>`) | Không cài dbt vào image Airflow; thêm/đổi tên model không phải sửa DAG |
| 6 | `simulate_new_data` | AdventureWorks là dữ liệu tĩnh; mô phỏng lần nạp dữ liệu mới để freshness có ý nghĩa |
| 7 | Health check / backup / restore **duyệt mọi bảng trong schema** | Đổi tên model không làm hỏng quy trình deploy |
| 8 | Production phải **duyệt thủ công** + tag mỗi phiên bản | Kiểm soát thay đổi; lịch sử phiên bản; rollback theo tag |
| 9 | Grafana ở **file compose riêng** | Không sửa hạ tầng gốc; chỉ bật khi cần |

## 6. Bảo mật

- Repo public: không có mật khẩu trong code; `.env` nằm trong `.gitignore`; pre-commit `detect-private-key`.
- Cổng SQL Server, Airflow, Grafana chỉ mở cho `127.0.0.1`.
- Trên GitHub Actions: mật khẩu sinh ngẫu nhiên cho mỗi lần chạy (hoặc lấy từ Environment secrets) và được che trong log.
- Production chỉ deploy từ nhánh được bảo vệ, có người duyệt.
