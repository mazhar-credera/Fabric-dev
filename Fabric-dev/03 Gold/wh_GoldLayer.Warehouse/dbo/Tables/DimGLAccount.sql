CREATE TABLE [dbo].[DimGLAccount] (

	[GLAccountSk] bigint IDENTITY NOT NULL, 
	[No] varchar(40) NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[Blocked] bit NOT NULL, 
	[GLAccountName] varchar(80) NOT NULL, 
	[AccountCategory] varchar(100) NOT NULL, 
	[AccountSubcategory] varchar(160) NOT NULL, 
	[AccountSubcategoryEntryNo] int NOT NULL, 
	[AccountType] varchar(100) NOT NULL, 
	[ConsolCreditAcc] varchar(40) NOT NULL, 
	[ConsolDebitAcc] varchar(40) NOT NULL, 
	[IncomeBalance] varchar(100) NOT NULL, 
	[DebitCredit] varchar(100) NOT NULL, 
	[DirectPosting] bit NOT NULL, 
	[ExchangeRateAdjustment] varchar(100) NOT NULL, 
	[SearchName] varchar(100) NOT NULL, 
	[VATBusPostingGroup] varchar(40) NOT NULL, 
	[VATProdPostingGroup] varchar(40) NOT NULL, 
	[_crda_Hash] varbinary(16) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimGLAccount] ADD CONSTRAINT PK__dbo_DimGLAccount primary key NONCLUSTERED ([GLAccountSk]);
GO
ALTER TABLE [dbo].[DimGLAccount] ADD CONSTRAINT UQ__dbo_DimGLAccount unique NONCLUSTERED ([No], [BcCompanySk]);