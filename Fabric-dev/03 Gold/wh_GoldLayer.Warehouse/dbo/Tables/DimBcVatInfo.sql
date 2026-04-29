CREATE TABLE [dbo].[DimBcVatInfo] (

	[BcVatInfoSk] int NOT NULL, 
	[VatBusPostingGroup] varchar(255) NOT NULL, 
	[VatProdPostingGroup] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimBcVatInfo] ADD CONSTRAINT PK__dbo_DimBcVatInfo primary key NONCLUSTERED ([BcVatInfoSk]);
GO
ALTER TABLE [dbo].[DimBcVatInfo] ADD CONSTRAINT UQ__dbo_DimBcVatInfo unique NONCLUSTERED ([VatBusPostingGroup], [VatProdPostingGroup]);