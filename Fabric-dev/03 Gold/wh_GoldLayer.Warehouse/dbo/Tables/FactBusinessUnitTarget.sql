CREATE TABLE [dbo].[FactBusinessUnitTarget] (

	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[BusinessUnitSk] int NOT NULL, 
	[RevenueTarget] decimal(18,3) NULL, 
	[EmpRevenueTarget] decimal(18,3) NULL, 
	[RevenueStretchTarget] decimal(18,3) NULL, 
	[OmcTarget] decimal(18,3) NULL, 
	[OmcStretchTarget] decimal(18,3) NULL, 
	[PbtOmcTarget] decimal(18,3) NULL, 
	[RevenueZeroPlusTwelveTarget] decimal(18,3) NULL, 
	[RevenueZeroPlusTwelveStretchTarget] decimal(18,3) NULL, 
	[ResourceBusinessDays] decimal(18,3) NULL, 
	[ResourceTrainingDays] decimal(18,3) NULL, 
	[ResourceHolidayDays] decimal(18,3) NULL, 
	[ResourceOtherDays] decimal(18,3) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_UpdatedDateTime] datetime2(6) NULL, 
	[_crda_PK_JoinHash] varbinary(16) NULL
);


GO
ALTER TABLE [dbo].[FactBusinessUnitTarget] ADD CONSTRAINT PK__dbo_FactBusinessUnitTarget primary key NONCLUSTERED ([PeriodStart], [PeriodEnd], [BusinessUnitSk]);