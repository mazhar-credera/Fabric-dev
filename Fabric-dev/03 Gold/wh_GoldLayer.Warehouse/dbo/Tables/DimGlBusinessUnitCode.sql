CREATE TABLE [dbo].[DimGlBusinessUnitCode] (

	[GlBusinessUnitCodeSk] bigint IDENTITY NOT NULL, 
	[BusinessUnitCode] varchar(255) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimGlBusinessUnitCode] ADD CONSTRAINT PK__dbo_DimGlBusinessUnitCode primary key NONCLUSTERED ([GlBusinessUnitCodeSk]);
GO
ALTER TABLE [dbo].[DimGlBusinessUnitCode] ADD CONSTRAINT UQ__dbo_DimGlBusinessUnitCode unique NONCLUSTERED ([BusinessUnitCode]);