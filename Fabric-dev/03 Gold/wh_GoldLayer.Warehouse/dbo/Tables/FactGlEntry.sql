CREATE TABLE [dbo].[FactGlEntry] (

	[GlEntrySk] bigint NOT NULL, 
	[BcCompanySk] bigint NOT NULL, 
	[GLAccountSk] bigint NOT NULL, 
	[GlBalAccountSk] bigint NOT NULL, 
	[GlDimensionCodeSk] bigint NOT NULL, 
	[BcVatInfoSk] bigint NOT NULL, 
	[PostingDate] date NULL, 
	[DocumentDate] date NULL, 
	[PostingDateSk] int NULL, 
	[DocumentDateSk] int NULL, 
	[Amount] decimal(18,2) NULL, 
	[CreditAmount] decimal(18,2) NULL, 
	[DebitAmount] decimal(18,2) NULL, 
	[VatAmount] decimal(18,2) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactGlEntry] ADD CONSTRAINT PK__dbo_FactGlEntry primary key NONCLUSTERED ([GlEntrySk], [BcCompanySk]);