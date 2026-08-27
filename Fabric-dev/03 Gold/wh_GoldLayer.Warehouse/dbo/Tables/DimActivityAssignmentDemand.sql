CREATE TABLE [dbo].[DimActivityAssignmentDemand] (

	[ActivityAssignmentDemandSk] int NOT NULL, 
	[ActivityAssignmentDemandBk] varchar(18) NOT NULL, 
	[Name] varchar(255) NOT NULL, 
	[ResourceSk] bigint NOT NULL, 
	[DeliveryGroupSk] bigint NOT NULL, 
	[ProposalSk] bigint NOT NULL, 
	[AccountSk] bigint NOT NULL, 
	[LocationSk] bigint NOT NULL, 
	[ActivityRole] varchar(1024) NULL, 
	[CurrencyIsoCode] varchar(3) NULL, 
	[DemandRef] varchar(255) NULL, 
	[ForecastStatusName] varchar(255) NULL, 
	[ProbabilityCode] varchar(255) NULL, 
	[UrlToKanataRecord] varchar(255) NOT NULL, 
	[StartDate] date NULL, 
	[EndDate] date NULL, 
	[StartDateSk] int NULL, 
	[EndDateSk] int NULL, 
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
ALTER TABLE [dbo].[DimActivityAssignmentDemand] ADD CONSTRAINT PK__dbo_DimActivityAssignmentDemand primary key NONCLUSTERED ([ActivityAssignmentDemandSk]);
GO
ALTER TABLE [dbo].[DimActivityAssignmentDemand] ADD CONSTRAINT UQ__dbo_DimActivityAssignmentDemand unique NONCLUSTERED ([ActivityAssignmentDemandBk], [_crda_ActiveFromDate]);
GO
ALTER TABLE [dbo].[DimActivityAssignmentDemand] ADD CONSTRAINT FK__dbo_DimActivityAssignmentDemand__EndDateSk__dbo_DimDate FOREIGN KEY ([EndDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);
GO
ALTER TABLE [dbo].[DimActivityAssignmentDemand] ADD CONSTRAINT FK__dbo_DimActivityAssignmentDemand__StartDateSk__dbo_DimDate FOREIGN KEY ([StartDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);
GO
ALTER TABLE [dbo].[DimActivityAssignmentDemand] ADD CONSTRAINT FK__dbo_DimActivityAssignmentDemand__crda_ActiveFromDateSk__dbo_DimDate FOREIGN KEY ([_crda_ActiveFromDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);
GO
ALTER TABLE [dbo].[DimActivityAssignmentDemand] ADD CONSTRAINT FK__dbo_DimActivityAssignmentDemand__crda_ActiveToDateSk__dbo_DimDate FOREIGN KEY ([_crda_ActiveToDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);