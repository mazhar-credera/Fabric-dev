CREATE TABLE [dbo].[DimDate] (

	[DateSk] int NOT NULL, 
	[Date] date NOT NULL, 
	[FullDate] varchar(10) NOT NULL, 
	[Year] int NOT NULL, 
	[Month] int NOT NULL, 
	[MonthName] varchar(10) NOT NULL, 
	[DayOfWeekName] varchar(10) NOT NULL, 
	[CalendarQuarter] int NOT NULL, 
	[WeekNumberInYear] int NOT NULL, 
	[DayNumberInWeek] int NOT NULL, 
	[DayNumberInMonth] int NOT NULL, 
	[DayNumberInYear] int NOT NULL, 
	[IsWeekDay] bit NOT NULL, 
	[DaysFromToday] int NOT NULL, 
	[MonthsFromToday] int NOT NULL, 
	[MonthYear] char(8) NOT NULL, 
	[FirstDayOfWeek] date NULL, 
	[FirstDayOfWorkWeek] date NULL, 
	[FirstDayOfMonth] date NOT NULL, 
	[LastDayOfMonth] date NOT NULL, 
	[FirstDayOfYear] date NOT NULL, 
	[LastDayOfYear] date NOT NULL, 
	[IsBankHoliday] bit NOT NULL, 
	[FiscalYear] int NOT NULL, 
	[FiscalQuarter] int NOT NULL, 
	[IsNonWorkDay] bit NOT NULL, 
	[_crda_ExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [dbo].[DimDate] ADD CONSTRAINT PK__dbo_DimDate primary key NONCLUSTERED ([DateSk]);
GO
ALTER TABLE [dbo].[DimDate] ADD CONSTRAINT UQ__dbo_DimDate unique NONCLUSTERED ([Date], [IsWeekDay], [IsBankHoliday]);