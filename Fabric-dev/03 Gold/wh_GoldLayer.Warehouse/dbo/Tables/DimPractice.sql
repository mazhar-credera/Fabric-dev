CREATE TABLE [dbo].[DimPractice] (

	[PracticeSk] int NOT NULL, 
	[PracticeBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[DisplayName] varchar(255) NOT NULL, 
	[FunctionName] varchar(255) NULL, 
	[PracticeName] varchar(255) NULL, 
	[CurrencyIsoCode] varchar(3) NOT NULL, 
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
ALTER TABLE [dbo].[DimPractice] ADD CONSTRAINT PK__dbo_DimPractice primary key NONCLUSTERED ([PracticeSk]);
GO
ALTER TABLE [dbo].[DimPractice] ADD CONSTRAINT UQ__dbo_DimPractice unique NONCLUSTERED ([PracticeBk], [_crda_ActiveFromDate]);