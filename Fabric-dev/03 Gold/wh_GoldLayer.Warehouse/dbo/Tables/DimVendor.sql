CREATE TABLE [dbo].[DimVendor] (

	[VendorSk] bigint IDENTITY NOT NULL, 
	[No] varchar(40) NOT NULL, 
	[BcCompanySk] bigint NOT NULL, 
	[VendorName] varchar(80) NOT NULL, 
	[Blocked] varchar(100) NOT NULL, 
	[BlockPaymentTolerance] bit NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[CashFlowPaymentTermsCode] varchar(20) NOT NULL, 
	[FinChargeTermsCode] varchar(20) NOT NULL, 
	[InvoiceDiscCode] varchar(40) NOT NULL, 
	[PaymentMethodCode] varchar(20) NOT NULL, 
	[PaymentTermsCode] varchar(20) NOT NULL, 
	[PreferredBankAccountCode] varchar(40) NOT NULL, 
	[PricesIncludingVAT] bit NOT NULL, 
	[ValidateEUVatRegNo] bit NOT NULL, 
	[VATBusPostingGroup] varchar(40) NOT NULL, 
	[VATRegistrationNo] varchar(40) NOT NULL, 
	[VendorPostingGroup] varchar(40) NOT NULL, 
	[DataSource] varchar(255) NOT NULL, 
	[_crda_Hash] varbinary(16) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimVendor] ADD CONSTRAINT PK__dbo_DimVendor primary key NONCLUSTERED ([VendorSk]);
GO
ALTER TABLE [dbo].[DimVendor] ADD CONSTRAINT UQ__dbo_DimVendor unique NONCLUSTERED ([No], [BcCompanySk]);