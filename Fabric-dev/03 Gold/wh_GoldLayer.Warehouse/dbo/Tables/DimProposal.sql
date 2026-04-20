CREATE TABLE [dbo].[DimProposal] (

	[ProposalSk] bigint IDENTITY NOT NULL, 
	[ProposalBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[ShortName] varchar(80) NOT NULL, 
	[Description] varchar(2000) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NULL, 
	[AccountSk] bigint NULL, 
	[BusinessUnitSk] bigint NULL, 
	[SalesOpportunitySk] bigint NULL, 
	[ForecastStatusSk] bigint NULL, 
	[PropositionSk] bigint NULL, 
	[ForecastAtDetailedLevel] bit NULL, 
	[AcceptanceDate] date NULL, 
	[DeliveryStartDate] date NULL, 
	[EarliestStartDate] date NULL, 
	[LatestEndDate] date NULL, 
	[ContractCost] decimal(18,2) NULL, 
	[ContractMargin] decimal(18,2) NULL, 
	[ContractMarginAmount] decimal(18,2) NULL, 
	[ContractRevenue] decimal(18,2) NULL, 
	[DetailedLevelContractCost] decimal(18,2) NULL, 
	[DetailedLevelContractRevenue] decimal(18,2) NULL, 
	[DetailedLevelWeightedContractRevenue] decimal(18,2) NULL, 
	[Discount] decimal(18,2) NULL, 
	[DiscountPercentage] decimal(10,2) NULL, 
	[HighLevelContractCost] decimal(18,2) NULL, 
	[HighLevelContractRevenue] decimal(18,2) NULL, 
	[HighLevelWeightedContractRevenue] decimal(18,2) NULL, 
	[NumberOfItems] decimal(18,2) NULL, 
	[ProposalCost] decimal(18,2) NULL, 
	[ProposalExpensesCost] decimal(18,2) NULL, 
	[ProposalMargin] decimal(18,2) NULL, 
	[ProposalMarginAmount] decimal(18,2) NULL, 
	[ProposalUsageCost] decimal(18,2) NULL, 
	[WeightedContractRevenue] decimal(18,2) NULL, 
	[DMWElementIsWAR] bit NULL, 
	[UrlToKantataRecord] varchar(255) NOT NULL, 
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
ALTER TABLE [dbo].[DimProposal] ADD CONSTRAINT PK__dbo_DimProposal primary key NONCLUSTERED ([ProposalSk]);
GO
ALTER TABLE [dbo].[DimProposal] ADD CONSTRAINT UQ__dbo_DimProposal unique NONCLUSTERED ([ProposalBk], [_crda_ActiveFromDate]);