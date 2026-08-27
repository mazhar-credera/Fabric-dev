CREATE TABLE [Internal].[ResourceAbsence] (

	[ResourceBk] varchar(18) NOT NULL, 
	[AbsenceStartDate] date NOT NULL, 
	[AbsenceEndDate] date NOT NULL, 
	[NumberOfDays] decimal(5,2) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[ResourceAbsence] ADD CONSTRAINT PK__Internal_ResourceAbsence primary key NONCLUSTERED ([ResourceBk], [AbsenceStartDate]);