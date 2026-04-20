CREATE TABLE [dbo].[DimOpportunitySource] (

	[OpportunitySourceSk] bigint IDENTITY NOT NULL, 
	[OpportunitySourceBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[OwnerSk] int NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[Enum] varchar(60) NOT NULL, 
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
ALTER TABLE [dbo].[DimOpportunitySource] ADD CONSTRAINT PK__dbo_DimOpportunitySource primary key NONCLUSTERED ([OpportunitySourceSk]);
GO
ALTER TABLE [dbo].[DimOpportunitySource] ADD CONSTRAINT UQ__dbo_DimOpportunitySource unique NONCLUSTERED ([OpportunitySourceBk], [_crda_ActiveFromDate]);