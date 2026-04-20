CREATE TABLE [Internal].[SalesOpportunityHistory] (

	[SalesOpportunityBk] varchar(18) NOT NULL, 
	[CreatedDate] datetime2(6) NOT NULL, 
	[SalesOpportunityCreated] datetime2(6) NULL, 
	[AccountBk] varchar(18) NULL, 
	[CloseDate] date NULL, 
	[CustomerAccountBk] varchar(18) NULL, 
	[ForecastStatusBk] varchar(18) NULL, 
	[Name] varchar(255) NULL, 
	[NewBusinessUpTo] varchar(18) NULL, 
	[OpportunityStageBk] varchar(18) NULL, 
	[OwnerId] varchar(18) NULL, 
	[ProposedDeliveryProgramBk] varchar(18) NULL, 
	[ResponseRequiredDate] date NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_UpdatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_UpdatedDateTime] datetime2(6) NULL
);


GO
ALTER TABLE [Internal].[SalesOpportunityHistory] ADD CONSTRAINT PK__Internal_SalesOpportunityHistory primary key NONCLUSTERED ([SalesOpportunityBk], [CreatedDate]);