CREATE TABLE [dbo].[DimMilestone] (

	[MilestoneSk] int NOT NULL, 
	[MilestoneBk] varchar(18) NOT NULL, 
	[MilestoneName] varchar(80) NOT NULL, 
	[MilestoneDate] date NOT NULL, 
	[BaselineMilestoneDate] date NULL, 
	[MilestoneDateSk] int NOT NULL, 
	[BaselineMilestoneDateSk] int NULL, 
	[MilestoneValue] decimal(18,2) NULL, 
	[SupplierInvoicingCurrencyMilestoneValue] decimal(18,2) NULL, 
	[CurrencyIsoCode] varchar(3) NULL, 
	[InvoicingCurrencyIsoCode] varchar(3) NULL, 
	[SupplierInvoicingCurrencyIsoCode] varchar(3) NULL, 
	[NavId] varchar(10) NULL, 
	[MilestoneDescription] varchar(255) NULL, 
	[DeliveryElementBk] varchar(18) NULL, 
	[MilestoneType] varchar(255) NULL, 
	[MilestoneStatus] varchar(255) NULL, 
	[DaysFromToday] int NOT NULL, 
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
ALTER TABLE [dbo].[DimMilestone] ADD CONSTRAINT PK__dbo_DimMilestone primary key NONCLUSTERED ([MilestoneSk]);
GO
ALTER TABLE [dbo].[DimMilestone] ADD CONSTRAINT UQ__dbo_DimMilestone unique NONCLUSTERED ([MilestoneBk], [_crda_ActiveFromDate]);