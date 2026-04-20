CREATE TABLE [dbo].[DimOpportunityStage] (

	[OpportunityStageSk] bigint IDENTITY NOT NULL, 
	[OpportunityStageBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[Description] varchar(255) NOT NULL, 
	[Sequence] smallint NOT NULL, 
	[SequencedName] varchar(255) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[RequiresDeliveryElementForecast] bit NOT NULL, 
	[DefaultForecastStatus] varchar(255) NOT NULL, 
	[RequiresCompletionApproval] bit NOT NULL, 
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
ALTER TABLE [dbo].[DimOpportunityStage] ADD CONSTRAINT PK__dbo_DimOpportunityStage primary key NONCLUSTERED ([OpportunityStageSk]);
GO
ALTER TABLE [dbo].[DimOpportunityStage] ADD CONSTRAINT UQ__dbo_DimOpportunityStage unique NONCLUSTERED ([OpportunityStageBk], [_crda_ActiveFromDate]);