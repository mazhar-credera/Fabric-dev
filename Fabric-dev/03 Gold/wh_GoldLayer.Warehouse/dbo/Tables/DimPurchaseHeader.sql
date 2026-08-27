CREATE TABLE [dbo].[DimPurchaseHeader] (

	[PurchaseHeaderSk] int NOT NULL, 
	[No] varchar(40) NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[DocumentType] varchar(80) NOT NULL, 
	[Status] varchar(80) NOT NULL, 
	[BalAccountType] varchar(80) NOT NULL, 
	[CurrencyCode] varchar(3) NOT NULL, 
	[DocumentDate] date NULL, 
	[DueDate] date NULL, 
	[ExpectedReceiptDate] date NULL, 
	[InvoiceReceiptDate] date NULL, 
	[OrderDate] date NULL, 
	[PostingDate] date NULL, 
	[PrepaymentDueDate] date NULL, 
	[BuyfromContactNo] varchar(80) NOT NULL, 
	[BuyfromVendorNo] varchar(80) NOT NULL, 
	[DimensionSetID] varchar(80) NOT NULL, 
	[PaytoContactNo] varchar(80) NOT NULL, 
	[PaytoVendorNo] varchar(80) NOT NULL, 
	[VendorInvoiceNo] varchar(80) NOT NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_isDeleted] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimPurchaseHeader] ADD CONSTRAINT PK__dbo_DimPurchaseHeader primary key NONCLUSTERED ([PurchaseHeaderSk]);
GO
ALTER TABLE [dbo].[DimPurchaseHeader] ADD CONSTRAINT UQ__dbo_DimPurchaseHeader unique NONCLUSTERED ([No], [BcCompanySk], [_crda_ActiveFromDate]);