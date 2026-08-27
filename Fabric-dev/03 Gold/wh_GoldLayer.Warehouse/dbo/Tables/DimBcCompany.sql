CREATE TABLE [dbo].[DimBcCompany] (

	[BcCompanySk] bigint IDENTITY NOT NULL, 
	[BC_CompanyName] varchar(100) NOT NULL, 
	[LegalEntity] varchar(100) NOT NULL, 
	[CompanyType] varchar(100) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimBcCompany] ADD CONSTRAINT PK__dbo_DimBcCompany primary key NONCLUSTERED ([BcCompanySk]);
GO
ALTER TABLE [dbo].[DimBcCompany] ADD CONSTRAINT UQ__dbo_DimBcCompany unique NONCLUSTERED ([BC_CompanyName]);