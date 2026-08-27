CREATE TABLE [dbo].[DimCustomer] (

	[CustomerSk] bigint IDENTITY NOT NULL, 
	[No] varchar(40) NOT NULL, 
	[BcCompanySk] bigint NOT NULL, 
	[Blocked] varchar(100) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[CustomerName] varchar(80) NOT NULL, 
	[SearchName] varchar(100) NOT NULL, 
	[CashFlowPaymentTermsCode] varchar(20) NOT NULL, 
	[ContactType] varchar(100) NOT NULL, 
	[BaseCalendarCode] varchar(20) NOT NULL, 
	[FinChargeTermsCode] varchar(20) NOT NULL, 
	[CountryRegionCode] varchar(20) NOT NULL, 
	[CreditLimitLCY] decimal(18,2) NOT NULL, 
	[AllowLineDisc] bit NOT NULL, 
	[InvoiceDiscCode] varchar(40) NOT NULL, 
	[LastStatementNo] int NOT NULL, 
	[PaymentTermsCode] varchar(20) NOT NULL, 
	[ValidateEUVatRegNo] bit NOT NULL, 
	[VATBusPostingGroup] varchar(40) NOT NULL, 
	[VATRegistrationNo] varchar(40) NOT NULL, 
	[DataSource] varchar(255) NOT NULL, 
	[_crda_Hash] varbinary(16) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimCustomer] ADD CONSTRAINT PK__dbo_DimCustomer primary key NONCLUSTERED ([CustomerSk]);
GO
ALTER TABLE [dbo].[DimCustomer] ADD CONSTRAINT UQ__dbo_DimCustomer unique NONCLUSTERED ([No], [BcCompanySk]);