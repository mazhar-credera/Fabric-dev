CREATE TABLE [dbo].[DimAnalysisFact] (

	[AnalysisFactSk] int NOT NULL, 
	[AnalysisFactBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[Description] varchar(80) NOT NULL, 
	[Enum] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
	[IsCurrency] bit NULL, 
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
ALTER TABLE [dbo].[DimAnalysisFact] ADD CONSTRAINT PK__dbo_DimAnalysisFact primary key NONCLUSTERED ([AnalysisFactSk]);
GO
ALTER TABLE [dbo].[DimAnalysisFact] ADD CONSTRAINT UQ__dbo_DimAnalysisFact unique NONCLUSTERED ([AnalysisFactBk], [_crda_ActiveFromDate]);
GO
ALTER TABLE [dbo].[DimAnalysisFact] ADD CONSTRAINT FK__dbo_DimAnalysisFact__crda_ActiveFromDateSk_dbo_DimDate FOREIGN KEY ([_crda_ActiveFromDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);
GO
ALTER TABLE [dbo].[DimAnalysisFact] ADD CONSTRAINT FK__dbo_DimAnalysisFact__crda_ActiveToDateSk_dbo_DimDate FOREIGN KEY ([_crda_ActiveToDateSk]) REFERENCES [dbo].[DimDate]([DateSk]);