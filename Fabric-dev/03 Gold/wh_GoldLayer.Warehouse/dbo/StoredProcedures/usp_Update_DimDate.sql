CREATE  
	PROCEDURE dbo.usp_Update_DimDate
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
AS 
BEGIN 
	SET NOCOUNT ON ;
/*
	=========================================================
	Create Date: 20230720
	Description: 
				Populates dbo.DimDate from prebaked
				Internal.DimDate table  
	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDate]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDate]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDate]')
	EXEC dbo.usp_Update_DimDate @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimDate ; 
	=========================================================
*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	BEGIN TRY

		IF ( DATENAME(WEEKDAY, GETUTCDATE()) IN ('Sunday', 'Wednesday')
			OR (SELECT COUNT(1) FROM dbo.DimDate) = 0) 
		BEGIN

			MERGE INTO	dbo.DimDate  
										AS TGT 
			USING	Internal.DimDate	AS SRC	ON	TGT.[DateSk] = SRC.DateKey
			WHEN MATCHED	
			THEN	UPDATE	
				SET TGT.[Date]				= SRC.[Date] ,
					TGT.[FullDate]			= CONVERT(VARCHAR(10), SRC.[Date], 103) , 
					TGT.[Year]				= SRC.[Year] , 
					TGT.[Month]				= SRC.[Month] , 
					TGT.[MonthName]			= SRC.[MonthName] , 
					TGT.[DayOfWeekName]		= SRC.WeekDayName , 
					TGT.[CalendarQuarter]	= SRC.[Quarter]	 , 
					TGT.[WeekNumberInYear]	= SRC.WeekOfYear , 
					TGT.[DayNumberInMonth]	= SRC.[Day] , 
					TGT.[IsWeekDay]			= IIF(SRC.IsWeekend = 1, 0, 1) , 
					TGT.DaysFromToday		= datediff(day, getutcdate(), SRC.[Date]) ,
					TGT.MonthsFromToday		= datediff(month, getutcdate(), SRC.[Date]) ,
					TGT.MonthYear			= SRC.ShortMonthYear , 
					TGT.FirstDayOfWeek		= SRC.FirstDayOfWeek , 
					TGT.FirstDayOfWorkWeek	= SRC.FirstDayOfWorkWeek , 
					TGT.FirstDayOfMonth		= SRC.FirstDayOfMonth , 
					TGT.LastDayOfMonth		= SRC.LastDayOfMonth , 
					TGT.FirstDayOfYear		= SRC.FirstDayOfYear , 
					TGT.LastDayOfYear		= SRC.LastDayOfYear , 
					TGT.[IsBankHoliday]		= SRC.IsBankHoliday , 
					TGT.[FiscalYear]		= SRC.[FiscalYear] , 
					TGT.[FiscalQuarter]		= SRC.[FiscalQuarter] , 
					TGT.IsNonWorkDay		= (case when [IsWeekDay]=(0) OR SRC.IsBankHoliday=(1) then (1) else (0) end), 
					TGT.[_crda_ExecutionId]	= @_ExecutionId , 
					TGT.[_crda_CreatedDateTime]	= GETUTCDATE() 
				
			WHEN NOT MATCHED BY TARGET 
			THEN INSERT( 
					 [DateSk]
					,[Date]
					,[FullDate]
					,[Year]
					,[Month]
					,[MonthName]
					,[DayOfWeekName]
					,[CalendarQuarter]
					,[WeekNumberInYear]
					,[DayNumberInWeek]
					,[DayNumberInMonth]
					,[DayNumberInYear]
					,[IsWeekDay]
					,DaysFromToday 
					,MonthsFromToday 

					,MonthYear
					,FirstDayOfWeek
					,FirstDayOfWorkWeek
					,FirstDayOfMonth
					,LastDayOfMonth
					,FirstDayOfYear
					,LastDayOfYear
					,IsBankHoliday
					,[FiscalYear]
					,[FiscalQuarter]
					,IsNonWorkDay 
					,[_crda_ExecutionId]
					,[_crda_CreatedDateTime]
				)
				VALUES( 
					SRC.DateKey , 
					SRC.[Date] ,
					CONVERT(VARCHAR(10), SRC.[Date], 103) ,
					SRC.[Year] ,
					SRC.[Month] ,
					SRC.[MonthName] , 
					SRC.WeekDayName , 
					SRC.[Quarter] , 
					SRC.WeekOfYear ,
					SRC.[Weekday] , 
					SRC.[Day] , 
					SRC.[DayOfYear] , 
					IIF(SRC.IsWeekend = 1, 0, 1) , 
					datediff(day, getutcdate(), SRC.[Date]) , 
					datediff(month, getutcdate(), SRC.[Date]) ,

					SRC.ShortMonthYear , 
					SRC.FirstDayOfWeek , 
					SRC.FirstDayOfWorkWeek , 
					SRC.FirstDayOfMonth , 
					SRC.LastDayOfMonth , 
					SRC.FirstDayOfYear , 
					SRC.LastDayOfYear , 
					SRC.IsBankHoliday , 
					SRC.FiscalYear , 
					SRC.FiscalQuarter , 
					(case when (IIF(SRC.IsWeekend = 1, 0, 1))=(0) OR SRC.IsBankHoliday=(1) then (1) else (0) end) ,
					@_ExecutionId , 
					GETUTCDATE()
				) ;


		END ; 

		SELECT	InitialWatermark	= '20000101', 
				UpdatedWatermark	= '20000101' ; 

	END TRY
	
	BEGIN CATCH
		THROW ;
	END CATCH;
	
END ;