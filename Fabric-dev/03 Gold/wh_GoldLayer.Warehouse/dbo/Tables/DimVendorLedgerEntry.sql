CREATE TABLE [dbo].[DimVendorLedgerEntry] (

	[VendorLedgerEntrySk] bigint IDENTITY NOT NULL, 
	[VendorLedgerEntryNo] int NOT NULL, 
	[DetailedLedgerEntryNo] int NOT NULL, 
	[BcCompanySk] bigint NOT NULL, 
	[VendorSk] bigint NOT NULL, 
	[VendorPostingGroupSK] bigint NOT NULL, 
	[GlBalAccountSk] bigint NOT NULL, 
	[GlDimensionCodeSk] bigint NOT NULL, 
	[PaymentTermsSK] bigint NOT NULL, 
	[LedgerEntryUserSk] bigint NOT NULL, 
	[DetailedLedgerEntryUserSk] bigint NOT NULL, 
	[CurrencyCode] varchar(255) NULL, 
	[Description] varchar(255) NULL, 
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
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimVendorLedgerEntry] ADD CONSTRAINT PK__dbo_DimVendorLedgerEntry primary key NONCLUSTERED ([VendorLedgerEntrySk]);
GO
ALTER TABLE [dbo].[DimVendorLedgerEntry] ADD CONSTRAINT UQ__dbo_DimVendorLedgerEntry unique NONCLUSTERED ([VendorLedgerEntryNo], [DetailedLedgerEntryNo], [BcCompanySk]);