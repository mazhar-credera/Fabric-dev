CREATE TABLE [dbo].[DimGlDimensionCode] (

	[GlDimensionCodeSk] bigint IDENTITY NOT NULL, 
	[GlobalDimension1Code] varchar(255) NOT NULL, 
	[GlobalDimension2Code] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimGlDimensionCode] ADD CONSTRAINT PK__dbo_DimGlDimensionCode primary key NONCLUSTERED ([GlDimensionCodeSk]);
GO
ALTER TABLE [dbo].[DimGlDimensionCode] ADD CONSTRAINT UQ__dbo_DimGlDimensionCode unique NONCLUSTERED ([GlobalDimension1Code], [GlobalDimension2Code]);