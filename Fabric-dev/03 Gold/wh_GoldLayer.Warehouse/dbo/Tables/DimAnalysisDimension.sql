CREATE TABLE [dbo].[DimAnalysisDimension] (

	[AnalysisDimensionSk] int NOT NULL, 
	[AnalysisDimensionBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[AnalysisLevel] bit NOT NULL, 
	[HasAccount] bit NOT NULL, 
	[HasBusinessUnit] bit NOT NULL, 
	[HasGrade] bit NOT NULL, 
	[HasProduct] bit NOT NULL, 
	[HasProposition] bit NOT NULL, 
	[HasResource] bit NOT NULL, 
	[HasResourceType] bit NOT NULL, 
	[HasUser] bit NOT NULL, 
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
ALTER TABLE [dbo].[DimAnalysisDimension] ADD CONSTRAINT PK__dbo_DimAnalysisDimension primary key NONCLUSTERED ([AnalysisDimensionSk]);
GO
ALTER TABLE [dbo].[DimAnalysisDimension] ADD CONSTRAINT UQ__dbo_DimAnalysisDimension unique NONCLUSTERED ([AnalysisDimensionBk], [_crda_ActiveFromDate]);