CREATE TABLE [dbo].[FactAccountTarget] (

	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[PeriodStartSk] int NULL, 
	[PeriodEndSk] int NULL, 
	[AccountSk] bigint NOT NULL, 
	[RevenueTargetAmount] decimal(18,3) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_PK_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactAccountTarget] ADD CONSTRAINT PK__dbo_FactAccountTarget primary key NONCLUSTERED ([PeriodStart], [PeriodEnd], [AccountSk]);