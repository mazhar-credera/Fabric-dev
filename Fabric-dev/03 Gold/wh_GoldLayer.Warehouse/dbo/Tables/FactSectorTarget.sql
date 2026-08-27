CREATE TABLE [dbo].[FactSectorTarget] (

	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[SectorSk] int NOT NULL, 
	[RevenueTargetAmount] decimal(18,3) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_PK_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactSectorTarget] ADD CONSTRAINT PK__dbo_FactSectorTarget primary key NONCLUSTERED ([PeriodStart], [PeriodEnd], [SectorSk]);