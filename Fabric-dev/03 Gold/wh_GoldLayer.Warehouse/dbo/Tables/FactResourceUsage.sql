CREATE TABLE [dbo].[FactResourceUsage] (

	[FactResourceUsageSk] int NOT NULL, 
	[ResourceSk] int NOT NULL, 
	[PeriodStartDate] date NOT NULL, 
	[PeriodEndDate] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[AccountSk] int NOT NULL, 
	[AnalysisFactSk] int NOT NULL, 
	[ResourcedActivityTypeSk] int NOT NULL, 
	[DeliveryGroupSk] int NOT NULL, 
	[DeliveryElementSk] int NOT NULL, 
	[DmwActivityTypeSk] int NOT NULL, 
	[ResourcedActivityNameSk] int NOT NULL, 
	[PracticeSk] int NOT NULL, 
	[GradeSk] int NOT NULL, 
	[AccountBusinessUnitSk] int NOT NULL, 
	[ResourceBusinessUnitSk] int NOT NULL, 
	[PaBusinessUnitSk] int NOT NULL, 
	[P1ForecastAmount] decimal(18,2) NOT NULL, 
	[P2ForecastAmount] decimal(18,2) NOT NULL, 
	[P3ForecastAmount] decimal(18,2) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactResourceUsage] ADD CONSTRAINT PK__dbo_FactResourceUsage primary key NONCLUSTERED ([FactResourceUsageSk]);