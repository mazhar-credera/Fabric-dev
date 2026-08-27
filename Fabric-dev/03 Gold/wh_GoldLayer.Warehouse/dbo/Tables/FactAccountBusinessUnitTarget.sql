CREATE TABLE [dbo].[FactAccountBusinessUnitTarget] (

	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[AccountSk] bigint NOT NULL, 
	[BusinessUnitSk] bigint NOT NULL, 
	[RevenueTargetAmount] decimal(18,3) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_PK_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactAccountBusinessUnitTarget] ADD CONSTRAINT PK__dbo_FactAccountBusinessUnitTarget primary key NONCLUSTERED ([PeriodStart], [PeriodEnd], [AccountSk], [BusinessUnitSk]);