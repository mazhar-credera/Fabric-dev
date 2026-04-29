CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactResourceHolidays
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	/*Groundhogday Load*/
	USAGE 

	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceHolidays]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceHolidays]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceHolidays]')
	EXEC dbo.usp_Update_FactResourceHolidays @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactResourceHolidays ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
	DECLARE	@DateIn12Months	DATE = DATEADD(MONTH, 13, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 


	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #FactResourceHolidays ;

			/*#FactResourceHolidays*/
			SELECT
				 PeriodStartDate= CAST(CP.KimbleOne__StartDate__c AS DATE) 
				,PeriodEndDate	= CAST(CP.KimbleOne__EndDate__c AS DATE) 
				,ResourceSk		= ISNULL(DR.ResourceSk, -1)
				,HolidayHours	= SUM(KimbleOne__EntryUnits__c)	
				,HolidayDays	= SUM(KimbleOne__EntryUnits__c)/8	
			INTO #FactResourceHolidays 
			FROM		lh_SilverLayer.Kantata.HISTORY_ForecastTimeEntry	T  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment	AA 	ON	AA.Id				= T.KimbleOne__ActivityAssignment__c
																AND AA._crda_isDeleted	= 0  
																AND	AA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON	TP.Id				= T.KimbleOne__TimePeriod__c
																AND TP._crda_isDeleted	= 0  
																AND	TP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			CP 	ON	CP.Id				= TP.KimbleOne__ForecastingTimePeriod__c
																AND CP._crda_isDeleted	= 0  
																AND	CP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			LEFT JOIN	dbo.DimResource						DR	ON	DR.ResourceBk		= T.KimbleOne__Resource__c 
																AND	DR.IsCurrent		= 1
			WHERE	AA.IsHoliday = 1

			AND		T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			AND		T._crda_isDeleted = 0 

			GROUP BY	
				 CAST(CP.KimbleOne__StartDate__c AS DATE)
				,CAST(CP.KimbleOne__EndDate__c AS DATE)
				,ISNULL(DR.ResourceSk, -1)

			ORDER BY	
				 CAST(CP.KimbleOne__StartDate__c AS DATE)
				,CAST(CP.KimbleOne__EndDate__c AS DATE)
				,ISNULL(DR.ResourceSk, -1)


			TRUNCATE TABLE dbo.FactResourceHolidays ;


			INSERT INTO dbo.FactResourceHolidays
			(	
				 FactResourceHolidaysSk 
				,PeriodStart
				,PeriodEnd
				,PeriodStartSk	
				,PeriodEndSk	


				,ResourceSk
				,HolidayHours
				,HolidayDays 

				,[_crda_ResourceHolidays_JoinHash] 

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT	
				ROW_NUMBER()OVER (ORDER BY A.PeriodStart, A.ResourceSk)  ,
				A.PeriodStart ,
				A.PeriodEnd , 
				A.ResourceSk ,
				(CONVERT([int],CONVERT([varchar](8),[PeriodStart],(112)))) ,
				(CONVERT([int],CONVERT([varchar](8),[PeriodEnd],(112)))) ,


				ISNULL(FS.HolidayHours ,0) ,
				ISNULL(FS.HolidayDays ,0) ,

				HASHBYTES('MD5', CONCAT_WS('||', A.PeriodStart, A.PeriodEnd, A.ResourceSk)) ,

				@_ExecutionId , 
				GETUTCDATE() 

			FROM	dbo.FN_GetResourceAllDates (@DateIn12Months)
												A 
			LEFT JOIN	#FactResourceHolidays	FS	ON	FS.PeriodStartDate	= A.PeriodStart 
													AND	FS.PeriodEndDate	= A.PeriodEnd 
													AND	FS.ResourceSk		= A.ResourceSk 

			ORDER BY	A.PeriodStart, 
						ResourceSk ; 



			SELECT	InitialWatermark	= @strOldWatermark, 
					UpdatedWatermark	= @strNewWatermark ; 

		COMMIT;

	END TRY
	BEGIN CATCH
		ROLLBACK;
		THROW;
	END CATCH ; 

	IF @@TRANCOUNT > 0 ROLLBACK; 

END;