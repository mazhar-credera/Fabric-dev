CREATE TABLE [Internal].[SalesOpportunityLifecycle] (

	[SalesOpportunityLifecycleSk] bigint IDENTITY NOT NULL, 
	[SalesOpportunityBk] varchar(18) NULL, 
	[SalesOpportunitytDateTime] datetime2(6) NOT NULL, 
	[AccountBk] varchar(18) NULL, 
	[AccountBusinessUnitBk] varchar(18) NULL, 
	[ProposalBk] varchar(18) NULL, 
	[ProposalBusinessUnitBk] varchar(18) NULL, 
	[RelatedSalesOpportunityBk] varchar(18) NULL, 
	[ForecastStatusBk] varchar(18) NULL, 
	[OpportunityStageBk] varchar(18) NULL, 
	[OpportunitySourceBk] varchar(18) NULL, 
	[SectorBk] varchar(18) NULL, 
	[PropositionBk] varchar(18) NULL, 
	[MarketingCampaignBk] varchar(18) NULL, 
	[ProposedDeliveryProgramBk] varchar(18) NULL, 
	[OriginatorBk] varchar(18) NULL, 
	[CommercialSignOffBk] varchar(18) NULL, 
	[SalesOpportunityOwnerBk] varchar(18) NULL, 
	[ProposalOwnerBk] varchar(18) NULL, 
	[CloseDate] date NULL, 
	[AcceptanceDate] date NULL, 
	[ResponseRequiredDate] date NULL, 
	[EarliestStartDate] date NULL, 
	[LatestEndDate] date NULL, 
	[DeliveryStartDate] date NULL, 
	[CloseDateSk] int NULL, 
	[AcceptanceDateSk] int NULL, 
	[ResponseRequiredDateSk] int NULL, 
	[EarliestStartDateSk] int NULL, 
	[LatestEndDateSk] int NULL, 
	[DeliveryStartDateSk] int NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[WonLostReason] varchar(255) NOT NULL, 
	[BidStatus] varchar(255) NULL, 
	[BidFramework] varchar(255) NULL, 
	[BidPQQDueDate] date NULL, 
	[BidPQQStatus] varchar(255) NULL, 
	[ContractRevenue] decimal(18,2) NOT NULL, 
	[ContractMargin] decimal(18,2) NOT NULL, 
	[ContractCost] decimal(18,2) NOT NULL, 
	[ContractMarginAmount] decimal(18,2) NOT NULL, 
	[ContractMarginPercentage] decimal(18,2) NOT NULL, 
	[WeightedContractRevenue] decimal(18,2) NOT NULL, 
	[IsForecastedAtDetailedLevel] bit NOT NULL, 
	[DetailedLevelContractCost] decimal(18,2) NOT NULL, 
	[DetailedLevelContractRevenue] decimal(18,2) NOT NULL, 
	[DetailedLevelWeightedContractRevenue] decimal(18,2) NOT NULL, 
	[HighLevelContractCost] decimal(18,2) NOT NULL, 
	[HighLevelContractRevenue] decimal(18,2) NOT NULL, 
	[HighLevelWeightedContractRevenue] decimal(18,2) NOT NULL, 
	[ProposalCost] decimal(18,2) NOT NULL, 
	[ProposalExpenseCost] decimal(18,2) NOT NULL, 
	[ProposalMarginAmount] decimal(18,2) NOT NULL, 
	[ProposalMarginPercentage] decimal(18,2) NOT NULL, 
	[ProposalUsageCost] decimal(18,2) NOT NULL, 
	[DiscountAmount] decimal(18,2) NOT NULL, 
	[DiscountPercentage] decimal(5,2) NOT NULL, 
	[DMWElementIsWAR] bit NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[SalesOpportunityLifecycle] ADD CONSTRAINT PK__Internal_FactSalesOpportunityLifecycle primary key NONCLUSTERED ([SalesOpportunityLifecycleSk]);
GO
ALTER TABLE [Internal].[SalesOpportunityLifecycle] ADD CONSTRAINT UQ__Internal_FactSalesOpportunityLifecycle unique NONCLUSTERED ([SalesOpportunityBk], [SalesOpportunitytDateTime]);