CREATE TABLE [Internal].[SalesOpportunity] (

	[SalesOpportunityBk] varchar(18) NOT NULL, 
	[SalesOpsCreatedDateTime] datetime2(6) NOT NULL, 
	[PerformanceAnalysisBk] varchar(18) NOT NULL, 
	[AccountBk] varchar(18) NULL, 
	[ProposalBk] varchar(18) NULL, 
	[SalesOpForecastStatusBk] varchar(18) NULL, 
	[PaForecastStatusBk] varchar(18) NULL, 
	[OpportunitySourceBk] varchar(18) NULL, 
	[SectorBk] varchar(18) NULL, 
	[AnalysisFactBk] varchar(18) NULL, 
	[PaBusinessUnitBk] varchar(18) NULL, 
	[TotalRevenue] decimal(18,2) NOT NULL, 
	[WeightedRevenue] decimal(18,2) NOT NULL, 
	[UnweightedRevenue] decimal(18,2) NOT NULL, 
	[_crda_ValidFromDateTime] datetime2(6) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[SalesOpportunity] ADD CONSTRAINT UQ__Internal_FactSalesOpportunity unique NONCLUSTERED ([SalesOpportunityBk], [SalesOpsCreatedDateTime], [PerformanceAnalysisBk]);