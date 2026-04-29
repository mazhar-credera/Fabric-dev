CREATE TABLE [dbo].[FactResourceHolidays] (

	[FactResourceHolidaysSk] int NOT NULL, 
	[PeriodStart] date NOT NULL, 
	[PeriodEnd] date NOT NULL, 
	[ResourceSk] int NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[HolidayHours] decimal(5,2) NOT NULL, 
	[HolidayDays] decimal(5,2) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL, 
	[_crda_ResourceHolidays_JoinHash] varbinary(16) NOT NULL
);


GO
ALTER TABLE [dbo].[FactResourceHolidays] ADD CONSTRAINT PK__dbo_FactResourceHolidays primary key NONCLUSTERED ([FactResourceHolidaysSk]);
GO
ALTER TABLE [dbo].[FactResourceHolidays] ADD CONSTRAINT UQ__dbo_FactResourceHolidays unique NONCLUSTERED ([PeriodStart], [ResourceSk]);