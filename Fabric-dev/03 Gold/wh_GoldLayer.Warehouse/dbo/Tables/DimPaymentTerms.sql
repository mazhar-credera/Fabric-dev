CREATE TABLE [dbo].[DimPaymentTerms] (

	[PaymentTermsSK] bigint IDENTITY NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[Code] varchar(20) NOT NULL, 
	[CalcPmtDisconCrMemos] bit NULL, 
	[Description] varchar(100) NULL, 
	[DiscountDateCalculation] varchar(400) NULL, 
	[DiscountP] decimal(18,2) NULL, 
	[DueDateCalculation] varchar(400) NULL, 
	[_crda_Hash] varbinary(16) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimPaymentTerms] ADD CONSTRAINT PK__dbo_DimPaymentTerms primary key NONCLUSTERED ([PaymentTermsSK]);
GO
ALTER TABLE [dbo].[DimPaymentTerms] ADD CONSTRAINT UQ__dbo_DimPaymentTerms unique NONCLUSTERED ([BcCompanySk], [Code]);