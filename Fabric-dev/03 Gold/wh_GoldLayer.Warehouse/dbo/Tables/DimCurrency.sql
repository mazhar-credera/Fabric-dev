CREATE TABLE [dbo].[DimCurrency] (

	[CurrencySk] int NOT NULL, 
	[CurrencyBk] varchar(3) NOT NULL, 
	[Currency] varchar(80) NOT NULL, 
	[CurrencyCountry] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[CurrencyIsoNumber] varchar(5) NOT NULL, 
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
ALTER TABLE [dbo].[DimCurrency] ADD CONSTRAINT PK__dbo_DimCurrency primary key NONCLUSTERED ([CurrencySk]);
GO
ALTER TABLE [dbo].[DimCurrency] ADD CONSTRAINT UQ__dbo_DimCurrency unique NONCLUSTERED ([CurrencyBk], [_crda_ActiveFromDate]);