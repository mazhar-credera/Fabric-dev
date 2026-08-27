CREATE TABLE [dbo].[FactVendorLedgerEntry] (

	[VendorLedgerEntrySk] int NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[VendorSk] int NOT NULL, 
	[VendorPostingGroupSK] int NOT NULL, 
	[GlBalAccountSk] int NOT NULL, 
	[GlDimensionCodeSk] int NOT NULL, 
	[PaymentTermsSK] int NOT NULL, 
	[BcVatInfoSk] int NOT NULL, 
	[LedgerEntryUserSk] int NOT NULL, 
	[DetailedLedgerEntryUserSk] int NOT NULL, 
	[ClosedatDate] date NULL, 
	[DocumentDate] date NULL, 
	[DueDate] date NULL, 
	[PostingDate] date NULL, 
	[InvoiceDate] date NULL, 
	[ClosedatDateSk] int NULL, 
	[DocumentDateSk] int NULL, 
	[DueDateSk] int NULL, 
	[PostingDateSk] int NULL, 
	[InvoiceDateSk] int NULL, 
	[CurrencyCode] varchar(20) NULL, 
	[Amount] decimal(18,2) NULL, 
	[AmountLCY] decimal(18,2) NULL, 
	[CreditAmount] decimal(18,2) NULL, 
	[CreditAmountLCY] decimal(18,2) NULL, 
	[DebitAmount] decimal(18,2) NULL, 
	[DebitAmountLCY] decimal(18,2) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactVendorLedgerEntry] ADD CONSTRAINT PK__dbo_FactVendorLedgerEntry primary key NONCLUSTERED ([VendorLedgerEntrySk]);