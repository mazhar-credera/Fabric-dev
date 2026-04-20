CREATE TABLE [dbo].[DimGlEntry] (

	[GlEntrySk] bigint IDENTITY NOT NULL, 
	[GlEntryNo] int NOT NULL, 
	[BcCompanySk] bigint NOT NULL, 
	[GLAccountSk] bigint NOT NULL, 
	[GlBalAccountSk] bigint NOT NULL, 
	[GlDimensionCodeSk] bigint NOT NULL, 
	[InvoiceNo] varchar(255) NULL, 
	[DocumentNo] varchar(255) NULL, 
	[ExternalDocumentNo] varchar(255) NULL, 
	[Description] varchar(255) NULL, 
	[SourceNo] varchar(255) NULL, 
	[SourceCode] varchar(255) NULL, 
	[SourceType] varchar(255) NULL, 
	[ClosingDate] bit NULL, 
	[PriorYearEntry] bit NULL, 
	[TaxLiable] bit NULL, 
	[TransactionNo] int NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimGlEntry] ADD CONSTRAINT PK__dbo_DimGlEntry primary key NONCLUSTERED ([GlEntrySk]);
GO
ALTER TABLE [dbo].[DimGlEntry] ADD CONSTRAINT UQ__dbo_DimGlEntry unique NONCLUSTERED ([GlEntryNo], [BcCompanySk]);