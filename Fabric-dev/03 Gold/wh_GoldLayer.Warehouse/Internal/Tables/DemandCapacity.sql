CREATE TABLE [Internal].[DemandCapacity] (

	[DemandCapacitySk] bigint IDENTITY NOT NULL, 
	[ActivityAssignmentBk] varchar(18) NULL, 
	[DemandCapacityType] varchar(50) NOT NULL, 
	[PeriodStartDate] date NOT NULL, 
	[PeriodEndDate] date NOT NULL, 
	[PeriodStartSk] int NOT NULL, 
	[PeriodEndSk] int NOT NULL, 
	[PeriodStartMonthEnd] date NOT NULL, 
	[PeriodEndMonthEnd] date NOT NULL, 
	[PeriodStartMonthEndSk] int NOT NULL, 
	[PeriodEndMonthEndSk] int NOT NULL, 
	[ResourceBk] varchar(18) NOT NULL, 
	[ResourcedActivityBk] varchar(18) NULL, 
	[ActivityAssignmentDemandBk] varchar(18) NULL, 
	[ActivityDemandStatusBk] varchar(18) NULL, 
	[CandidateStatusBk] varchar(18) NULL, 
	[ActivityAssgnRoleBk] varchar(18) NULL, 
	[ActivityDeliveryGroupBk] varchar(18) NULL, 
	[DeliveryGroupAccountBk] varchar(18) NULL, 
	[ResourcedActivityBusinessUnitBk] varchar(18) NULL, 
	[ReferenceDataBk] varchar(18) NULL, 
	[ResourcingStatusBk] varchar(18) NULL, 
	[ResourceDeliveryElementBk] varchar(18) NULL, 
	[DeliveryGroupForecastStatusBk] varchar(18) NULL, 
	[UtilisationPercentage] decimal(12,6) NOT NULL, 
	[TotalActualCost] decimal(18,2) NULL, 
	[ForecastP1Cost] decimal(18,2) NULL, 
	[ForecastP2Cost] decimal(18,2) NULL, 
	[ForecastP3Cost] decimal(18,2) NULL, 
	[TotalActualUsage] decimal(18,2) NULL, 
	[ForecastP1Usage] decimal(18,2) NULL, 
	[ForecastP2Usage] decimal(18,2) NULL, 
	[ForecastP3Usage] decimal(18,2) NULL, 
	[ForecastRevenueRate] decimal(18,2) NULL, 
	[TotalActualRevenue] decimal(18,2) NULL, 
	[ForecastP1Revenue] decimal(18,2) NULL, 
	[ForecastP2Revenue] decimal(18,2) NULL, 
	[ForecastP3Revenue] decimal(18,2) NULL, 
	[DemandRef] varchar(255) NULL, 
	[_crda_CreatedExecutionId] int NOT NULL, 
	[_crda_CreatedDateTime] datetime2(6) NOT NULL
);


GO
ALTER TABLE [Internal].[DemandCapacity] ADD CONSTRAINT PK__Internal_DemandCapacity primary key NONCLUSTERED ([DemandCapacitySk]);