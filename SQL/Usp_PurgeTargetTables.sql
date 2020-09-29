use SQL0319
go
CREATE PROCEDURE dbo.Usp_PurgeTargetTables
AS
BEGIN
delete from SalesLT.Product
delete from SalesLT.ProductModelProductDescription
delete from SalesLT.ProductDescription
delete from SalesLT.ProductModel
delete from SalesLT.ProductCategory
END
;