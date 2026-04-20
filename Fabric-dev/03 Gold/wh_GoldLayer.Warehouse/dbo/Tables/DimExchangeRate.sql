CREATE TABLE [dbo].[DimExchangeRate] (

	[ExchangeRateSk] bigint IDENTITY NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[RateEffectiveStartDate] datetime2(6) NOT NULL, 
	[RateEffectiveEndDate] datetime2(6) NOT NULL, 
	[ConversionFactorRate] decimal(18,6) NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimExchangeRate] ADD CONSTRAINT PK__dbo_DimExchangeRate primary key NONCLUSTERED ([ExchangeRateSk]);
GO
ALTER TABLE [dbo].[DimExchangeRate] ADD CONSTRAINT UQ__dbo_DimExchangeRate unique NONCLUSTERED ([CurrencyIsoCode], [RateEffectiveStartDate]);