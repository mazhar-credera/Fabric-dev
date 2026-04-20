CREATE TABLE [dbo].[DimBankAccountLedgerEntry] (

	[BankAccountLedgerEntrySk] bigint IDENTITY NOT NULL, 
	[BankAccountLedgerEntryNo] int NOT NULL, 
	[BcCompanySk] bigint NOT NULL, 
	[BankAccountSk] bigint NOT NULL, 
	[GlBalAccountSk] bigint NOT NULL, 
	[GlDimensionCodeSk] bigint NOT NULL, 
	[BcUserSk] bigint NOT NULL, 
	[InvoiceNo] varchar(255) NULL, 
	[DocumentNo] varchar(255) NULL, 
	[ExternalDocumentNo] varchar(255) NULL, 
	[Description] varchar(255) NULL, 
	[SourceCode] varchar(255) NULL, 
	[CurrencyCode] varchar(255) NULL, 
	[BankAccPostingGroup] varchar(255) NULL, 
	[DimensionSetID] int NULL, 
	[DocumentType] varchar(255) NULL, 
	[JournalBatchName] varchar(255) NULL, 
	[ReasonCode] varchar(255) NULL, 
	[ClosedbyEntryNo] bit NULL, 
	[Open] bit NULL, 
	[Positive] bit NULL, 
	[Reversed] bit NULL, 
	[ReversedbyEntryNo] int NULL, 
	[StatementLineNo] int NULL, 
	[StatementNo] varchar(255) NULL, 
	[StatementStatus] varchar(255) NULL, 
	[TransactionNo] int NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimBankAccountLedgerEntry] ADD CONSTRAINT PK__dbo_DimBankAccountLedgerEntry primary key NONCLUSTERED ([BankAccountLedgerEntrySk]);
GO
ALTER TABLE [dbo].[DimBankAccountLedgerEntry] ADD CONSTRAINT UQ__dbo_DimBankAccountLedgerEntry unique NONCLUSTERED ([BankAccountLedgerEntryNo], [BcCompanySk]);