CREATE TABLE [dbo].[FactCompanyTarget] (

	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[NewBusinessTargetAmount] decimal(18,3) NULL, 
	[AccountMgmtTargetAmount] decimal(18,3) NULL, 
	[CompanyTargetAmount] decimal(18,3) NULL, 
	[CompanyStretchTargetAmount] decimal(18,3) NULL, 
	[NumberOfBusinessDays] decimal(18,3) NULL, 
	[NumberOfOtherDays] decimal(18,3) NULL, 
	[CompanyTargetMargin] decimal(18,2) NULL, 
	[CompanyTargetPercent] decimal(9,2) NULL, 
	[CompanyTargetAssociateMargin] decimal(18,2) NULL, 
	[CompanyTargetAssociatePercent] decimal(9,2) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_PK_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactCompanyTarget] ADD CONSTRAINT PK__dbo_FactCompanyTarget primary key NONCLUSTERED ([PeriodStart], [PeriodEnd]);