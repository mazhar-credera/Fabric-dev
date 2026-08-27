CREATE TABLE [dbo].[DimCustLedgerEntry] (

	[CustLedgerEntrySk] int NOT NULL, 
	[CustLedgerEntryNo] int NOT NULL, 
	[DetailedLedgerEntryNo] int NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[CustomerSk] int NOT NULL, 
	[GlBalAccountSk] int NOT NULL, 
	[LedgerEntryUserSk] int NOT NULL, 
	[DetailedLedgerEntryUserSk] int NOT NULL, 
	[ExternalDocumentNo] varchar(255) NULL, 
	[InvoiceNo] varchar(255) NULL, 
	[CustomerPostingGroup] varchar(255) NULL, 
	[DocumentNo] varchar(255) NULL, 
	[InitialDocumentType] varchar(255) NULL, 
	[DocumentType] varchar(255) NULL, 
	[OnHold] varchar(255) NULL, 
	[Open] bit NULL, 
	[Positive] bit NULL, 
	[Reversed] bit NULL, 
	[TransactionNo] int NULL, 
	[UseTax] bit NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimCustLedgerEntry] ADD CONSTRAINT PK__dbo_DimCustLedgerEntry primary key NONCLUSTERED ([CustLedgerEntrySk]);
GO
ALTER TABLE [dbo].[DimCustLedgerEntry] ADD CONSTRAINT UQ__dbo_DimCustLedgerEntry unique NONCLUSTERED ([CustLedgerEntryNo], [DetailedLedgerEntryNo], [BcCompanySk]);