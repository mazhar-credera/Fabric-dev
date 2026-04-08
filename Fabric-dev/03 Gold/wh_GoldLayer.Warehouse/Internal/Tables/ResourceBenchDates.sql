CREATE TABLE [Internal].[ResourceBenchDates] (

	[ResourceBk] varchar(18) NOT NULL, 
	[BenchStartDate] date NOT NULL, 
	[BenchEndDate] date NOT NULL, 
	[NumberOfDays] int NOT NULL, 
	[UtilisationPercentage] decimal(9,3) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[ResourceBenchDates] ADD CONSTRAINT PK__Internal_ResourceBenchDates primary key NONCLUSTERED ([ResourceBk], [BenchStartDate]);