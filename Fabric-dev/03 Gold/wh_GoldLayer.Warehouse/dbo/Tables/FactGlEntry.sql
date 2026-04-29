CREATE TABLE [dbo].[FactGlEntry] (

	[GlEntrySk] int NOT NULL, 
	[BcCompanySk] int NOT NULL, 
	[GLAccountSk] int NOT NULL, 
	[GlBalAccountSk] int NOT NULL, 
	[GlDimensionCodeSk] int NOT NULL, 
	[BcVatInfoSk] int NOT NULL, 
	[PostingDate] date NULL, 
	[DocumentDate] date NULL, 
	[PostingDateSk] int NOT NULL, 
	[DocumentDateSk] int NOT NULL, 
	[Amount] decimal(18,2) NULL, 
	[CreditAmount] decimal(18,2) NULL, 
	[DebitAmount] decimal(18,2) NULL, 
	[VatAmount] decimal(18,2) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactGlEntry] ADD CONSTRAINT PK__dbo_FactGlEntry primary key NONCLUSTERED ([GlEntrySk], [BcCompanySk]);