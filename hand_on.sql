SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
ORDER BY SCHEMA_NAME;

SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;


SELECT TOP 10
    CustomerID,
    PersonID,
    StoreID,
    TerritoryID,
    AccountNumber
FROM Sales.Customer;

SELECT TOP 10
    SalesOrderID,
    CustomerID,
    OrderDate,
    TotalDue,
    Status
FROM Sales.SalesOrderHeader
ORDER BY OrderDate DESC;

SELECT TOP 10
    ProductID,
    Name,
    ProductNumber,
    Color,
    ListPrice
FROM Production.Product
WHERE DiscontinuedDate IS NULL;

