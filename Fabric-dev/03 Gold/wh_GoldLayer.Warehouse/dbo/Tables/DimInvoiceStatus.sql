CREATE TABLE [dbo].[DimInvoiceStatus] (

	[InvoiceStatusSk] int NOT NULL, 
	[InvoiceStatusBk] varchar(18) NOT NULL, 
	[InvoiceStatus] varchar(255) NOT NULL, 
	[InvoiceDomain] varchar(255) NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimInvoiceStatus] ADD CONSTRAINT PK__dbo_DimInvoiceStatus primary key NONCLUSTERED ([InvoiceStatusSk]);
GO
ALTER TABLE [dbo].[DimInvoiceStatus] ADD CONSTRAINT UQ__dbo_DimInvoiceStatus unique NONCLUSTERED ([InvoiceStatusBk]);