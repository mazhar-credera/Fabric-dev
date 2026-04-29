CREATE TABLE [dbo].[DimResource] (

	[ResourceSk] int NOT NULL, 
	[ResourceBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[FirstName] varchar(80) NOT NULL, 
	[LastName] varchar(80) NOT NULL, 
	[Email] varchar(1024) NULL, 
	[ContractualBase] varchar(80) NULL, 
	[LocationName] varchar(1024) NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[ActualCost] decimal(18,2) NOT NULL, 
	[ActualCostUnitType] varchar(80) NOT NULL, 
	[BusinessUnitSk] int NOT NULL, 
	[OwnerSk] int NOT NULL, 
	[GradeSk] int NOT NULL, 
	[PracticeSk] int NOT NULL, 
	[StartDate] date NULL, 
	[EndDate] date NULL, 
	[ContinuousServiceStart] date NULL, 
	[LatestP1AssignmentEndDate] date NULL, 
	[Notes] varchar(8000) NOT NULL, 
	[LengthOfService] decimal(7,2) NULL, 
	[BillableFTE] varchar(80) NULL, 
	[ResourceTypeBk] varchar(18) NULL, 
	[ResourceType] varchar(80) NULL, 
	[MandatoryScreeningCompleted] int NULL, 
	[DateScreeningDue] date NULL, 
	[ScreeningStatus] int NULL, 
	[ScreeningDue] int NULL, 
	[ScreeningOverdue] int NULL, 
	[DateLastScreening] date NULL, 
	[RightToWorkEndDate] date NULL, 
	[VisaStatus] varchar(80) NULL, 
	[ActiveVisaType] varchar(80) NULL, 
	[VettingStatus] varchar(80) NULL, 
	[RTWStatus] int NULL, 
	[ProvisionalEndDate] date NULL, 
	[AppraiserName] varchar(80) NULL, 
	[ReasonForClose] varchar(1024) NULL, 
	[ResourceId] varchar(30) NULL, 
	[Source] varchar(1024) NULL, 
	[ExperienceSummary] varchar(1024) NULL, 
	[Region] varchar(1024) NULL, 
	[TimePattern] varchar(1024) NULL, 
	[ResourceManagerName] varchar(80) NULL, 
	[UrlToKanataRecord] varchar(1024) NOT NULL, 
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
ALTER TABLE [dbo].[DimResource] ADD CONSTRAINT PK__dbo_DimResource primary key NONCLUSTERED ([ResourceSk]);
GO
ALTER TABLE [dbo].[DimResource] ADD CONSTRAINT UQ__dbo_DimResource unique NONCLUSTERED ([ResourceBk], [_crda_ActiveFromDate]);