CREATE TABLE [dbo].[DimBusinessUnit] (

	[BusinessUnitSk] int NOT NULL, 
	[BusinessUnitBk] varchar(18) NOT NULL, 
	[BusinessUnitName] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[TaxCodeReference] varchar(80) NOT NULL, 
	[ExpenseItemSubmissionDays] int NOT NULL, 
	[ExpenseItemExchangeRateTolerancePct] decimal(5,2) NOT NULL, 
	[CreditNoteFooter] varchar(1024) NOT NULL, 
	[InvoiceFooter] varchar(1024) NOT NULL, 
	[InvoiceBusinessUnitName] varchar(255) NOT NULL, 
	[InvoiceCurrencyIsoCode] varchar(3) NOT NULL, 
	[InvoiceTaxCodeNumber] varchar(255) NOT NULL, 
	[InvoicePaymentTermDays] int NOT NULL, 
	[InvoicingAddress] varchar(255) NOT NULL, 
	[InvoicingStreetName] varchar(255) NOT NULL, 
	[InvoicingStreet] varchar(255) NOT NULL, 
	[InvoicingCity] varchar(255) NOT NULL, 
	[InvoicingState] varchar(255) NOT NULL, 
	[InvoicingCountry] varchar(255) NOT NULL, 
	[InvoicingPostCode] varchar(10) NOT NULL, 
	[IsOperatingEntity] bit NOT NULL, 
	[IsTradingEntity] bit NOT NULL, 
	[IsPrimaryOrganisationalEntity] bit NOT NULL, 
	[IsSecondaryOrganisationalEntity] bit NOT NULL, 
	[IsActive] bit NOT NULL, 
	[IsDefault] bit NOT NULL, 
	[BudgetCode] varchar(10) NOT NULL, 
	[TimePattern] varchar(80) NOT NULL, 
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
ALTER TABLE [dbo].[DimBusinessUnit] ADD CONSTRAINT PK__dbo_DimBusinessUnit primary key NONCLUSTERED ([BusinessUnitSk]);
GO
ALTER TABLE [dbo].[DimBusinessUnit] ADD CONSTRAINT UQ__dbo_DimBusinessUnit unique NONCLUSTERED ([BusinessUnitBk], [_crda_ActiveFromDate]);