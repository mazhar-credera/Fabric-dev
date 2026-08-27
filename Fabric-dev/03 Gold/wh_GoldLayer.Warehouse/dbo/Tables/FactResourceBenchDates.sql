CREATE TABLE [dbo].[FactResourceBenchDates] (

	[ResourceSk] int NOT NULL, 
	[BenchStartDate] date NOT NULL, 
	[BenchEndDate] date NOT NULL, 
	[BenchStartDateSk] int NOT NULL, 
	[BenchEndDateSk] int NOT NULL, 
	[NumberOfDays] int NOT NULL, 
	[UtilisationPercentage] decimal(9,3) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[FactResourceBenchDates] ADD CONSTRAINT PK__dbo_FactResourceBenchDates primary key NONCLUSTERED ([ResourceSk], [BenchStartDate]);