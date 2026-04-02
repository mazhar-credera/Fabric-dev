CREATE TABLE [Internal].[DimDate] (

	[DateKey] int NOT NULL, 
	[Date] date NOT NULL, 
	[Day] smallint NOT NULL, 
	[DaySuffix] char(2) NOT NULL, 
	[Weekday] smallint NOT NULL, 
	[WeekDayName] varchar(10) NOT NULL, 
	[IsWeekend] bit NOT NULL, 
	[IsHoliday] bit NOT NULL, 
	[IsBankHoliday] bit NOT NULL, 
	[HolidayText] varchar(64) NULL, 
	[DOWInMonth] smallint NOT NULL, 
	[DayOfYear] smallint NOT NULL, 
	[WeekOfMonth] smallint NOT NULL, 
	[WeekOfYear] smallint NOT NULL, 
	[ISOWeekOfYear] smallint NOT NULL, 
	[Month] smallint NOT NULL, 
	[MonthName] varchar(10) NOT NULL, 
	[Quarter] smallint NOT NULL, 
	[QuarterName] varchar(6) NOT NULL, 
	[QuarterYear] varchar(7) NOT NULL, 
	[Half] smallint NOT NULL, 
	[HalfName] varchar(6) NOT NULL, 
	[Year] int NOT NULL, 
	[MMYYYY] char(6) NOT NULL, 
	[ShortMonthYear] char(8) NOT NULL, 
	[LongMonthYear] char(20) NOT NULL, 
	[TaxYear] char(7) NOT NULL, 
	[TaxQuarter] smallint NOT NULL, 
	[FiscalYear] int NOT NULL, 
	[FiscalQuarter] smallint NOT NULL, 
	[WeekEnding] date NOT NULL, 
	[FirstDayOfWeek] date NULL, 
	[FirstDayOfWorkWeek] date NULL, 
	[FirstDayOfMonth] date NOT NULL, 
	[LastDayOfMonth] date NOT NULL, 
	[FirstDayOfQuarter] date NOT NULL, 
	[LastDayOfQuarter] date NOT NULL, 
	[FirstDayOfHalf] date NOT NULL, 
	[LastDayOfHalf] date NOT NULL, 
	[FirstDayOfYear] date NOT NULL, 
	[LastDayOfYear] date NOT NULL, 
	[FirstDayOfNextMonth] date NOT NULL, 
	[FirstDayOfNextYear] date NOT NULL, 
	[IsNonWorkDay] int NOT NULL
);


GO
ALTER TABLE [Internal].[DimDate] ADD CONSTRAINT PK__Internal_DimDate primary key NONCLUSTERED ([DateKey]);