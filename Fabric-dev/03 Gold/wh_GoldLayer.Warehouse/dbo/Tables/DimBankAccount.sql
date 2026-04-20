CREATE TABLE [dbo].[DimBankAccount] (

	[BankAccountSk] bigint IDENTITY NOT NULL, 
	[No] varchar(40) NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[AccountName] varchar(80) NOT NULL, 
	[SearchName] varchar(100) NOT NULL, 
	[Blocked] bit NOT NULL, 
	[BalanceLastStatement] decimal(18,2) NULL, 
	[LastStatementNo] varchar(40) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimBankAccount] ADD CONSTRAINT PK__dbo_DimBankAccount primary key NONCLUSTERED ([BankAccountSk]);
GO
ALTER TABLE [dbo].[DimBankAccount] ADD CONSTRAINT UQ__dbo_DimBankAccount unique NONCLUSTERED ([No], [BcCompanySk]);