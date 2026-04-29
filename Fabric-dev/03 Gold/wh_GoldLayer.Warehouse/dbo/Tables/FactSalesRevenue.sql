CREATE TABLE [dbo].[FactSalesRevenue] (

	[FactSalesRevenueSk] int NOT NULL, 
	[PeriodStartDate] date NULL, 
	[PeriodEndDate] date NULL, 
	[PeriodStartDateSk] int NOT NULL, 
	[PeriodEndDateSk] int NOT NULL, 
	[FinancialReportingPeriodEndSk] int NULL, 
	[AccountSk] int NOT NULL, 
	[PaBusinessUnitSk] int NULL, 
	[ProposalSk] int NOT NULL, 
	[SalesOpportunitySk] int NULL, 
	[ForecastStatusSk] int NOT NULL, 
	[CurrencySk] int NOT NULL, 
	[AnalysisFactSk] int NULL, 
	[AnalysisDimensionSk] int NOT NULL, 
	[DeliveryPracticeSk] int NOT NULL, 
	[ResourceSk] int NULL, 
	[ResourcePracticeSk] int NOT NULL, 
	[PropositionSk] int NOT NULL, 
	[DeliveryGroupSk] int NULL, 
	[DeliveryElementSk] int NULL, 
	[ActualRevenue] decimal(18,2) NOT NULL, 
	[WeightedP1OnlyExcActual] decimal(18,2) NOT NULL, 
	[WeightedP2Only] decimal(18,2) NOT NULL, 
	[WeightedP3Only] decimal(18,2) NOT NULL, 
	[FirmRevenue] decimal(18,2) NULL, 
	[TotalRevenue] decimal(18,2) NOT NULL, 
	[RevenueSummary] decimal(18,2) NULL, 
	[CostSummary] decimal(18,2) NULL, 
	[WeightedRevenue] decimal(18,2) NOT NULL, 
	[UnweightedRevenue] decimal(18,2) NOT NULL, 
	[UnweightedP1OnlyExcActual] decimal(18,2) NULL, 
	[UnweightedP2Only] decimal(18,2) NULL, 
	[UnweightedP3Only] decimal(18,2) NULL, 
	[WeightedP1_Actual] decimal(18,2) NOT NULL, 
	[WeightedP1_P2_Actual] decimal(18,2) NOT NULL, 
	[Weighted_P1_P2_P3_Actual] decimal(18,2) NOT NULL, 
	[RevenueGenerationModel] varchar(255) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_FactSalesRevenueAccountTarget_JoinHash] varbinary(16) NOT NULL, 
	[_crda_FactSalesRevenuePaBusinessUnitTarget_JoinHash] varbinary(16) NOT NULL, 
	[_crda_FactSalesRevenuePaBusinessUnitAccountTarget_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactSalesRevenue] ADD CONSTRAINT PK__dbo_FactSalesRevenue primary key NONCLUSTERED ([FactSalesRevenueSk]);