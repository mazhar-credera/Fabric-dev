CREATE TABLE [dbo].[DimBcVatINfo] (

	[BcVatINfoSk] bigint IDENTITY NOT NULL, 
	[VatBusPostingGroup] varchar(255) NOT NULL, 
	[VatProdPostingGroup] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimBcVatINfo] ADD CONSTRAINT PK__dbo_DimBcVatINfo primary key NONCLUSTERED ([BcVatINfoSk]);
GO
ALTER TABLE [dbo].[DimBcVatINfo] ADD CONSTRAINT UQ__dbo_DimBcVatINfo unique NONCLUSTERED ([VatBusPostingGroup], [VatProdPostingGroup]);