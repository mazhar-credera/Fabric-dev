CREATE TABLE [Internal].[ResourceAccountHistory] (

	[PerformanceAnalysisBk] varchar(18) NOT NULL, 
	[ResourceBk] varchar(18) NOT NULL, 
	[AccountBk] varchar(18) NULL, 
	[TimePeriodBk] varchar(18) NOT NULL, 
	[PeriodStartDate] date NOT NULL, 
	[PeriodEndDate] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[P1ForecastResourceUsageDelivery] decimal(18,2) NULL, 
	[P2ForecastResourceUsageDelivery] decimal(18,2) NULL, 
	[P3ForecastResourceUsageDelivery] decimal(18,2) NULL, 
	[FactoredP1ForecastResourceUsageDelivery] decimal(18,2) NULL, 
	[FactoredP2ForecastResourceUsageDelivery] decimal(18,2) NULL, 
	[FactoredP3ForecastResourceUsageDelivery] decimal(18,2) NULL, 
	[P1ForecastRevenue] decimal(18,2) NULL, 
	[P2ForecastRevenue] decimal(18,2) NULL, 
	[P3ForecastRevenue] decimal(18,2) NULL, 
	[RecordType] varchar(255) NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL
);


GO
ALTER TABLE [Internal].[ResourceAccountHistory] ADD CONSTRAINT PK__Internal_ResourceAccountHistory primary key NONCLUSTERED ([PerformanceAnalysisBk]);