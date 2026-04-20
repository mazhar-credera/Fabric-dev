CREATE TABLE [dbo].[DimDeliveryElement] (

	[DeliveryElementSk] int NOT NULL, 
	[DeliveryElementBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[ShortName] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[StartDate] date NULL, 
	[EndDate] date NULL, 
	[EarliestAssignmentStartDate] date NULL, 
	[LatestAssignmentEndDate] date NULL, 
	[DeliveryGroupSk] bigint NULL, 
	[ForecastStatusSk] bigint NULL, 
	[OriginatingProposalSk] bigint NULL, 
	[PracticeSk] bigint NULL, 
	[ProductSk] bigint NULL, 
	[ProposalSk] bigint NULL, 
	[Reference] varchar(100) NULL, 
	[ContractMargin] decimal(18,2) NULL, 
	[ContractMarginAmount] decimal(18,2) NULL, 
	[ContractRevenue] decimal(18,2) NULL, 
	[WeightedContractRevenue] decimal(18,2) NULL, 
	[LegalReview] varchar(255) NULL, 
	[LegalReviewComments] varchar(4000) NULL, 
	[RiskReview] varchar(50) NULL, 
	[WARApprovedUntil] date NULL, 
	[TaxCodeBk] varchar(18) NULL, 
	[ExcludeFromCashflowUntil] date NULL, 
	[UrlToKanataPoRecord] varchar(255) NOT NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_isDeleted] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimDeliveryElement] ADD CONSTRAINT PK__dbo_DimDeliveryElement primary key NONCLUSTERED ([DeliveryElementSk]);
GO
ALTER TABLE [dbo].[DimDeliveryElement] ADD CONSTRAINT UQ__dbo_DimDeliveryElement unique NONCLUSTERED ([DeliveryElementBk], [_crda_ActiveFromDate]);