CREATE TABLE [dbo].[DimInvoiceableItem] (

	[InvoiceableItemSk] bigint IDENTITY NOT NULL, 
	[InvoiceableItemBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[InvoiceItemAge] decimal(18,0) NULL, 
	[InvoiceableUsage] decimal(18,2) NULL, 
	[CurrencyIsoCode] varchar(3) NULL, 
	[IsInternal] bit NULL, 
	[NirStatus] varchar(80) NULL, 
	[Type] varchar(80) NULL, 
	[OutboundInterfaceRunFg] bit NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_UpdatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_UpdatedDateTime] datetime2(6) NULL, 
	[_crda_IsActive] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimInvoiceableItem] ADD CONSTRAINT PK__dbo_DimInvoiceableItem primary key NONCLUSTERED ([InvoiceableItemSk]);
GO
ALTER TABLE [dbo].[DimInvoiceableItem] ADD CONSTRAINT UQ__dbo_DimInvoiceableItem unique NONCLUSTERED ([InvoiceableItemBk], [_crda_ActiveFromDate]);