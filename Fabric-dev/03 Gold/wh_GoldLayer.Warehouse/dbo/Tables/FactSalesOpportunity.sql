CREATE TABLE [dbo].[FactSalesOpportunity] (

	[FactSalesOpportunitySk] int NOT NULL, 
	[SalesOpportunitySk] int NOT NULL, 
	[AccountSk] int NOT NULL, 
	[ProposalSk] int NOT NULL, 
	[SalesOpForecastStatusSk] int NOT NULL, 
	[PaForecastStatusSk] int NOT NULL, 
	[OpportunitySourceSk] int NOT NULL, 
	[SectorSk] int NOT NULL, 
	[AnalysisFactSk] int NOT NULL, 
	[PaBusinessUnitSk] int NOT NULL, 
	[TotalRevenue] decimal(18,2) NOT NULL, 
	[WeightedRevenue] decimal(18,2) NOT NULL, 
	[UnweightedRevenue] decimal(18,2) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactSalesOpportunity] ADD CONSTRAINT PK__dbo_FactSalesOpportunity primary key NONCLUSTERED ([FactSalesOpportunitySk]);