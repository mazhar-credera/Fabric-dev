CREATE TABLE [dbo].[DimSalesOpportunityHistory] (

	[SalesOpportunityHistorySk] bigint IDENTITY NOT NULL, 
	[SalesOpportunityBk] varchar(18) NOT NULL, 
	[OpportunityCreatedDate] datetime2(6) NOT NULL, 
	[OpportunityCreatedDateSk] int NOT NULL, 
	[CurrentStageName] varchar(80) NULL, 
	[PreviousStageName] varchar(80) NULL, 
	[LastStageChangeDate] datetime2(6) NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_IsActive] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimSalesOpportunityHistory] ADD CONSTRAINT PK__dbo_DimSalesOpportunityHistory primary key NONCLUSTERED ([SalesOpportunityHistorySk]);
GO
ALTER TABLE [dbo].[DimSalesOpportunityHistory] ADD CONSTRAINT UQ__dbo_DimSalesOpportunityHistory unique NONCLUSTERED ([SalesOpportunityBk], [_crda_ActiveFromDate]);