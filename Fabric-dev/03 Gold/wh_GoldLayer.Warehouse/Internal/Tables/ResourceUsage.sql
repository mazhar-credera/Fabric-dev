CREATE TABLE [Internal].[ResourceUsage] (

	[ResourceUsageId] bigint IDENTITY NOT NULL, 
	[ResourceBk] varchar(18) NOT NULL, 
	[PeriodStartDate] date NOT NULL, 
	[PeriodEndDate] date NOT NULL, 
	[PerformanceAnalysisBk] varchar(18) NOT NULL, 
	[AccountBk] varchar(18) NULL, 
	[AnalysisFactBk] varchar(18) NULL, 
	[ResourcedActivityTypeBk] varchar(18) NULL, 
	[DeliveryGroupBk] varchar(18) NULL, 
	[DeliveryElementBk] varchar(18) NULL, 
	[DmwActivityType] varchar(255) NULL, 
	[ResourcedActivityDisplayName] varchar(255) NULL, 
	[PracticeBk] varchar(18) NULL, 
	[GradeBk] varchar(18) NULL, 
	[AccountBusinessUnitBk] varchar(18) NULL, 
	[ResourceBusinessUnitBk] varchar(18) NULL, 
	[PaBusinessUnitBk] varchar(18) NULL, 
	[P1ForecastAmount] decimal(18,2) NOT NULL, 
	[P2ForecastAmount] decimal(18,2) NOT NULL, 
	[P3ForecastAmount] decimal(18,2) NOT NULL, 
	[_crda_ActiveFromDateTime] datetime2(6) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[ResourceUsage] ADD CONSTRAINT PK__Internal_ResourceUsage primary key NONCLUSTERED ([ResourceUsageId]);
GO
ALTER TABLE [Internal].[ResourceUsage] ADD CONSTRAINT UQ__Internal_ResourceUsage unique NONCLUSTERED ([ResourceBk], [PeriodStartDate], [PerformanceAnalysisBk]);