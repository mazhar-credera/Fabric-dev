CREATE TABLE [dbo].[FactBusinessUnitByGradeTarget] (

	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[BusinessUnitSk] int NOT NULL, 
	[GradeSk] int NOT NULL, 
	[AverageRevenueRate] decimal(18,3) NULL, 
	[DeliveryUtilisationPct] decimal(18,2) NULL, 
	[RevenueTarget] decimal(18,3) NULL, 
	[DeliveryResourceCount] decimal(18,3) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_PK_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactBusinessUnitByGradeTarget] ADD CONSTRAINT PK__dbo_FactBusinessUnitByGradeTarget primary key NONCLUSTERED ([PeriodStart], [PeriodEnd], [BusinessUnitSk], [GradeSk]);