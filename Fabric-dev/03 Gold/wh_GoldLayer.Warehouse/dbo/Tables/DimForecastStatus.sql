CREATE TABLE [dbo].[DimForecastStatus] (

	[ForecastStatusSk] bigint IDENTITY NOT NULL, 
	[ForecastStatusBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[ShortName] varchar(8) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[Probability] decimal(5,2) NOT NULL, 
	[Contingency] decimal(5,2) NULL, 
	[StyleClass] varchar(30) NOT NULL, 
	[IsDelivery] bit NULL, 
	[ProbabilityCode] varchar(255) NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_IsActive] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimForecastStatus] ADD CONSTRAINT PK__dbo_DimForecastStatus primary key NONCLUSTERED ([ForecastStatusSk]);
GO
ALTER TABLE [dbo].[DimForecastStatus] ADD CONSTRAINT UQ__dbo_DimForecastStatus unique NONCLUSTERED ([ForecastStatusBk], [_crda_ActiveFromDate]);