CREATE TABLE [Internal].[ResourceMonthlyTargetDays] (

	[PeriodStartDate] date NOT NULL, 
	[PeriodEndDate] date NOT NULL, 
	[BusinessUnitBk] varchar(18) NOT NULL, 
	[TargetBusinessDays] decimal(18,2) NOT NULL, 
	[TargetTrainingDays] decimal(18,2) NOT NULL, 
	[TargetHolidaysDays] decimal(18,2) NOT NULL, 
	[TargetOtherDays] decimal(18,2) NOT NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[ResourceMonthlyTargetDays] ADD CONSTRAINT UQ__dbo_ResourceMonthlyTargetDays unique NONCLUSTERED ([PeriodStartDate], [BusinessUnitBk]);