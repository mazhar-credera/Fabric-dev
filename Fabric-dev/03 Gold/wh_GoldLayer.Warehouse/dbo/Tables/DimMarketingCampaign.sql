CREATE TABLE [dbo].[DimMarketingCampaign] (

	[MarketingCampaignSk] bigint IDENTITY NOT NULL, 
	[MarketingCampaignBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[Type] varchar(50) NOT NULL, 
	[Status] varchar(50) NOT NULL, 
	[OwnerSk] int NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[ActualCost] decimal(18,2) NOT NULL, 
	[StartDate] date NOT NULL, 
	[EndDate] date NOT NULL, 
	[ParentMarketingCampaignSk] bigint NOT NULL, 
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
ALTER TABLE [dbo].[DimMarketingCampaign] ADD CONSTRAINT PK__dbo_DimMarketingCampaign primary key NONCLUSTERED ([MarketingCampaignSk]);
GO
ALTER TABLE [dbo].[DimMarketingCampaign] ADD CONSTRAINT UQ__dbo_DimMarketingCampaign unique NONCLUSTERED ([MarketingCampaignBk], [_crda_ActiveFromDate]);