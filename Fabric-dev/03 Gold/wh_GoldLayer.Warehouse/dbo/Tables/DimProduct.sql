CREATE TABLE [dbo].[DimProduct] (

	[ProductSk] int NOT NULL, 
	[ProductBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[Description] varchar(max) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[BusinessUnitSk] int NOT NULL, 
	[Sage200NominalAccount] varchar(50) NULL, 
	[Sage50NominalAccount] varchar(50) NULL, 
	[SageInstantNominalAccount] varchar(50) NULL, 
	[IsActive] bit NOT NULL, 
	[IsAbstract] bit NOT NULL, 
	[IsPrimary] bit NOT NULL, 
	[IsRestricted] bit NOT NULL, 
	[AbstractionTypeBk] varchar(18) NULL, 
	[ProductType] varchar(80) NOT NULL, 
	[NavNominal] int NULL, 
	[_crda_ActiveFromDate] datetime2(6) NOT NULL, 
	[_crda_ActiveToDate] datetime2(6) NOT NULL, 
	[_crda_ActiveFromDateSk] int NOT NULL, 
	[_crda_ActiveToDateSk] int NOT NULL, 
	[IsCurrent] bit NOT NULL, 
	[_crda_Hash] varbinary(16) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_isDeleted] bit NOT NULL
);


GO
ALTER TABLE [dbo].[DimProduct] ADD CONSTRAINT PK__dbo_DimProduct primary key NONCLUSTERED ([ProductSk]);
GO
ALTER TABLE [dbo].[DimProduct] ADD CONSTRAINT UQ__dbo_DimProduct unique NONCLUSTERED ([ProductBk], [_crda_ActiveFromDate]);