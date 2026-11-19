{#-
    Mô phỏng một lần NẠP DỮ LIỆU MỚI vào hệ thống nguồn.

    Vì sao cần? AdventureWorks là dữ liệu tĩnh (2011–2014) nên kiểm tra source freshness
    (cột ModifiedDate) luôn báo lỗi. Macro này cập nhật ModifiedDate = thời điểm hiện tại cho
    N đơn hàng mới nhất và các bản ghi liên quan (dòng chi tiết, khách hàng, người, sản phẩm,
    danh mục) — giống như hệ thống nguồn vừa ghi nhận thay đổi.

    Trigger nghiệp vụ của AdventureWorks (vd. tự cập nhật tổng tiền) được tạm tắt trong lúc cập nhật
    để không làm thay đổi dữ liệu khác.

    Cách chạy:
        dbt run-operation simulate_new_data                      # 20 đơn hàng
        dbt run-operation simulate_new_data --args '{n_orders: 50}'
-#}
{% macro simulate_new_data(n_orders=20) %}

    {% set sql %}
        set nocount on;
        -- Một transaction + xact_abort: lỗi ở BẤT KỲ câu nào → hoàn tác TẤT CẢ, kể cả lệnh tắt trigger
        -- (không bao giờ để trigger bị tắt lại giữa chừng)
        set xact_abort on;
        begin transaction;

        declare @now datetime = getdate();
        declare @orders table (SalesOrderID int primary key);

        insert into @orders (SalesOrderID)
        select top ({{ n_orders }}) SalesOrderID
        from Sales.SalesOrderHeader
        order by SalesOrderID desc;

        -- Đơn hàng
        alter table Sales.SalesOrderHeader disable trigger all;
        update Sales.SalesOrderHeader set ModifiedDate = @now
        where SalesOrderID in (select SalesOrderID from @orders);
        alter table Sales.SalesOrderHeader enable trigger all;

        -- Dòng chi tiết của các đơn đó
        alter table Sales.SalesOrderDetail disable trigger all;
        update Sales.SalesOrderDetail set ModifiedDate = @now
        where SalesOrderID in (select SalesOrderID from @orders);
        alter table Sales.SalesOrderDetail enable trigger all;

        -- Khách hàng đặt các đơn đó
        alter table Sales.Customer disable trigger all;
        update Sales.Customer set ModifiedDate = @now
        where CustomerID in (
            select h.CustomerID
            from Sales.SalesOrderHeader as h
            inner join @orders as o on h.SalesOrderID = o.SalesOrderID
        );
        alter table Sales.Customer enable trigger all;

        -- Người tương ứng với các khách hàng đó
        alter table Person.Person disable trigger all;
        update Person.Person set ModifiedDate = @now
        where BusinessEntityID in (
            select PersonID from Sales.Customer
            where ModifiedDate = @now and PersonID is not null
        );
        alter table Person.Person enable trigger all;

        -- Sản phẩm có trong các đơn đó, rồi danh mục con và danh mục lớn của chúng
        alter table Production.Product disable trigger all;
        update Production.Product set ModifiedDate = @now
        where ProductID in (
            select d.ProductID
            from Sales.SalesOrderDetail as d
            inner join @orders as o on d.SalesOrderID = o.SalesOrderID
        );
        alter table Production.Product enable trigger all;

        alter table Production.ProductSubcategory disable trigger all;
        update Production.ProductSubcategory set ModifiedDate = @now
        where ProductSubcategoryID in (
            select ProductSubcategoryID from Production.Product
            where ModifiedDate = @now and ProductSubcategoryID is not null
        );
        alter table Production.ProductSubcategory enable trigger all;

        alter table Production.ProductCategory disable trigger all;
        update Production.ProductCategory set ModifiedDate = @now
        where ProductCategoryID in (
            select ProductCategoryID from Production.ProductSubcategory
            where ModifiedDate = @now
        );
        alter table Production.ProductCategory enable trigger all;

        commit transaction;
    {% endset %}

    {% do run_query(sql) %}
    {{ log("✅ Đã mô phỏng dữ liệu mới: cập nhật ModifiedDate cho " ~ n_orders ~ " đơn hàng mới nhất và các bản ghi liên quan.", info=True) }}

{% endmacro %}
