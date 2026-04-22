CREATE TABLE [dbo].[DimGrade] (

	[GradeSk] int NOT NULL, 
	[GradeBk] varchar(18) NOT NULL, 
	[Name] varchar(80) NOT NULL, 
	[CurrencyIsoCode] varchar(3) NULL, 
	[GradeShortName] varchar(5) NULL, 
	[GradeSortOrder] varchar(3) NULL, 
	[IsFeeEarning] bit NULL, 
	[GradeSortConcat] varchar(90) NULL, 
	[NAVRevenueDimension] varchar(100) NULL, 
	[GradeGroupBk] varchar(18) NULL, 
	[GradeGroupName] varchar(80) NULL, 
	[GradeGroupShortName] varchar(50) NULL, 
	[GradeGroupSortName] varchar(50) NULL, 
	[GroupofGroups] varchar(50) NULL, 
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
ALTER TABLE [dbo].[DimGrade] ADD CONSTRAINT PK__dbo_DimGrade primary key NONCLUSTERED ([GradeSk]);
GO
ALTER TABLE [dbo].[DimGrade] ADD CONSTRAINT UQ__dbo_DimGrade unique NONCLUSTERED ([GradeBk], [_crda_ActiveFromDate]);