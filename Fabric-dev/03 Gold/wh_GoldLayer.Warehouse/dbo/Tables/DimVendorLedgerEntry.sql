CREATE TABLE [dbo].[DimVendorLedgerEntry] (

	[VendorLedgerEntrySk] int NOT NULL, 
	[VendorLedgerEntryNo] int NOT NULL, 
	[DetailedLedgerEntryNo] int NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[VendorSk] int NOT NULL, 
	[VendorPostingGroupSK] int NOT NULL, 
	[GlBalAccountSk] int NOT NULL, 
	[GlDimensionCodeSk] int NOT NULL, 
	[PaymentTermsSK] int NOT NULL, 
	[LedgerEntryUserSk] int NOT NULL, 
	[DetailedLedgerEntryUserSk] int NOT NULL, 
	[CurrencyCode] varchar(255) NULL, 
	[Description] varchar(8000) NULL, 
	[InvoiceNo] varchar(255) NULL, 
	[DocumentNo] varchar(255) NULL, 
	[ExternalDocumentNo] varchar(255) NULL, 
	[DocumentType] varchar(255) NULL, 
	[CreditorNo] varchar(255) NULL, 
	[JournalBatchName] varchar(255) NULL, 
	[TransactionNo] int NULL, 
	[OnHold] varchar(255) NULL, 
	[Open] bit NULL, 
	[PaymentReference] varchar(255) NULL, 
	[Positive] bit NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimVendorLedgerEntry] ADD CONSTRAINT PK__dbo_DimVendorLedgerEntry primary key NONCLUSTERED ([VendorLedgerEntrySk]);
GO
ALTER TABLE [dbo].[DimVendorLedgerEntry] ADD CONSTRAINT UQ__dbo_DimVendorLedgerEntry unique NONCLUSTERED ([VendorLedgerEntryNo], [DetailedLedgerEntryNo], [BcCompanySk]);