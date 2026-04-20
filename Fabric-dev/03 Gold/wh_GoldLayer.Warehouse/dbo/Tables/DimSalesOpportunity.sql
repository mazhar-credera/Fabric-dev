CREATE TABLE [dbo].[DimSalesOpportunity] (

	[SalesOpportunitySk] bigint IDENTITY NOT NULL, 
	[SalesOpportunityBk] varchar(18) NOT NULL, 
	[Name] varchar(120) NOT NULL, 
	[Description] varchar(2000) NOT NULL, 
	[AccountViewName] varchar(80) NOT NULL, 
	[SOReference] varchar(512) NOT NULL, 
	[LinkToProposal] varchar(255) NOT NULL, 
	[ServiceProposition] varchar(255) NOT NULL, 
	[TypeofWork] varchar(80) NOT NULL, 
	[CloseDate] date NULL, 
	[ResponseRequiredDate] date NULL, 
	[EarliestStartDate] date NULL, 
	[LatestEndDate] date NULL, 
	[IsNewBusiness] bit NULL, 
	[DeliveryStatus] varchar(80) NULL, 
	[DeliverySplit] varchar(80) NULL, 
	[WonLostReason] varchar(255) NULL, 
	[ClosePlanAccurate] varchar(255) NULL, 
	[StandardRateCardUsed] varchar(255) NULL, 
	[OrganicGrowth] varchar(255) NULL, 
	[UrlToKanataRecord] varchar(255) NOT NULL, 
	[UrlToKanataDmwRecord] varchar(255) NOT NULL, 
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
ALTER TABLE [dbo].[DimSalesOpportunity] ADD CONSTRAINT PK__dbo_DimSalesOpportunity primary key NONCLUSTERED ([SalesOpportunitySk]);
GO
ALTER TABLE [dbo].[DimSalesOpportunity] ADD CONSTRAINT UQ__dbo_DimSalesOpportunity unique NONCLUSTERED ([SalesOpportunityBk], [_crda_ActiveFromDate]);