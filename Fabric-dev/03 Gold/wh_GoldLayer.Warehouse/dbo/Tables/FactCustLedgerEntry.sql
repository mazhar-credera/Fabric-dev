CREATE TABLE [dbo].[FactCustLedgerEntry] (

	[CustLedgerEntrySk] int NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[CustomerSk] int NOT NULL, 
	[GlBalAccountSk] int NOT NULL, 
	[LedgerEntryUserSk] int NOT NULL, 
	[DetailedLedgerEntryUserSk] int NOT NULL, 
	[ClosedatDate] date NULL, 
	[DocumentDate] date NULL, 
	[DueDate] date NULL, 
	[InitialEntryDueDate] date NULL, 
	[InvoiceDate] date NULL, 
	[OriginalDueDate] date NULL, 
	[PostingDate] date NULL, 
	[ClosedatDateSk] int NULL, 
	[DocumentDateSk] int NULL, 
	[DueDateSk] int NULL, 
	[InitialEntryDueDateSk] int NULL, 
	[InvoiceDateSk] int NULL, 
	[OriginalDueDateSk] int NULL, 
	[PostingDateSk] int NULL, 
	[CurrencyCode] varchar(20) NULL, 
	[Amount] decimal(18,2) NULL, 
	[AmountLCYExcVAT] decimal(18,2) NULL, 
	[AmountLCYIncVAT] decimal(18,2) NULL, 
	[CreditAmount] decimal(18,2) NULL, 
	[CreditAmountLCY] decimal(18,2) NULL, 
	[DebitAmount] decimal(18,2) NULL, 
	[DebitAmountLCY] decimal(18,2) NULL, 
	[LedgerEntryAmount] bit NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactCustLedgerEntry] ADD CONSTRAINT PK__dbo_FactCustLedgerEntry primary key NONCLUSTERED ([CustLedgerEntrySk], [BcCompanySk]);