CREATE TABLE [dbo].[FactBankAccountLedgerEntry] (

	[BankAccountLedgerEntrySk] int NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[BankAccountSk] int NOT NULL, 
	[GlBalAccountSk] int NOT NULL, 
	[GlDimensionCodeSk] int NOT NULL, 
	[BcUserSk] int NOT NULL, 
	[ClosedatDate] date NULL, 
	[PostingDate] date NULL, 
	[DocumentDate] date NULL, 
	[ClosedatDateSk] int NULL, 
	[PostingDateSk] int NULL, 
	[DocumentDateSk] int NULL, 
	[Amount] decimal(18,2) NULL, 
	[AmountLCY] decimal(18,2) NULL, 
	[CreditAmount] decimal(18,2) NULL, 
	[CreditAmountLCY] decimal(18,2) NULL, 
	[DebitAmount] decimal(18,2) NULL, 
	[DebitAmountLCY] decimal(18,2) NULL, 
	[RemainingAmount] decimal(18,2) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactBankAccountLedgerEntry] ADD CONSTRAINT PK__dbo_FactBankAccountLedgerEntry primary key NONCLUSTERED ([BankAccountLedgerEntrySk], [BcCompanySk]);