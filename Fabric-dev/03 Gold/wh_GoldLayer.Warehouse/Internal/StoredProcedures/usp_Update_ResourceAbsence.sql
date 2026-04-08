CREATE  
	PROCEDURE Internal.usp_Update_ResourceAbsence
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT  
WITH RECOMPILE 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM Meta.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceAbsence]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM Meta.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceAbsence]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM Meta.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceAbsence]')
	EXEC Internal.usp_Update_ResourceAbsence @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM Internal.ResourceAbsence ; --8445 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME = CAST(@Watermark AS DATETIME2) ,
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow	DATETIME2= GETUTCDATE() ;
	DECLARE	@PastDate	DATE ; 
	DECLARE	@FutureDate	DATE ; 

	SELECT	@PastDate	= PastDate ,
			@FutureDate	= FutureDate
	FROM	Tools.FN_GetPastAndFutureDates (-24, 2);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #ResourceAbsence ; 

			/*#ResourceAbsence*/
			SELECT
				 ResourceBk		= T.KimbleOne__Resource__c 
				,AbsenceDate	= CAST(TP.KimbleOne__StartDate__c AS DATE) 
				,HolidayHours	= T.KimbleOne__EntryUnits__c
				,T._crda_ActiveFromDateTime 
			INTO #ResourceAbsence 
			FROM		lh_SilverLayer.Kantata.HISTORY_ForecastTimeEntry	T  
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment	AA 	ON	AA.Id				= T.KimbleOne__ActivityAssignment__c
																				AND AA._crda_isDeleted	= 0 
																				AND	AA._crda_ActiveToDateTime = '9999-12-31 23:59:59'

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	TP 	ON	TP.Id				= T.KimbleOne__TimePeriod__c 
																		AND TP._crda_isDeleted	= 0 
																		AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																		AND	TP.KimbleOne__PeriodType__c = 'a1DD0000000UHKsMAO'	/*BusDay*/

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id				= AA.KimbleOne__ResourcedActivity__c
																				AND RA._crda_isDeleted	= 0 
																				AND	RA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																				AND	RA.Activity_Group__c IN  ('Absence', 'People') 

			WHERE	T._crda_ActiveFromDateTime > @PastDate  
			AND		T._crda_ActiveToDateTime = '9999-12-31 23:59:59'
			AND		T._crda_isDeleted = 0  
			AND		CAST(TP.KimbleOne__StartDate__c AS DATE) BETWEEN @PastDate AND @FutureDate 
			--AND		T.KimbleOne__Resource__c IN ('a1X3z000003Qsx9EAC' ) 
			; 

			/*SELECT * FROM #ResourceAbsence ORDER BY ResourceBk, AbsenceDate*/

			/*
				Gaps and Islands to generate Start and End dates for Absences 
					of continuous dates (including those that straddle weekends and bank holidays
			*/
			TRUNCATE TABLE Internal.ResourceAbsence ;

			;WITH cteIdentifyGaps
			AS(
				SELECT	 F.ResourceBk, F.PeriodStart, RR.AbsenceDate
						,RR.HolidayHours
						,IsAbsence = IIF(RR.AbsenceDate IS NOT NULL, 1, 0)
						,RN				= ROW_NUMBER() 
												OVER( 
													PARTITION BY F.ResourceBk
													ORDER BY	 F.PeriodStart
												) 
						,Gaps			= ROW_NUMBER() 
												OVER( 
													PARTITION BY F.ResourceBk , IIF(RR.AbsenceDate IS NOT NULL, 1, 0)
													ORDER BY	 F.PeriodStart
												) 

				FROM	Internal.FN_GetExplodeActiveDatesForResource(@PastDate, @FutureDate) F 
				LEFT JOIN (
							SELECT	 R.ResourceBk
									,R.AbsenceDate 
									,HolidayHours	= SUM(R.HolidayHours)
							FROM	#ResourceAbsence R 
							--WHERE	ResourceBk = 'a1X3z000003Qsx9EAC' 
							GROUP BY ResourceBk, AbsenceDate
				)		RR	ON	RR.ResourceBk	= F.ResourceBk 
							AND	RR.AbsenceDate	= F.PeriodStart 
				/*			AND	R.ResourceBk IN ('a1X8e000001foz4EAA', 'a1X4K000000K8xfUAC' )
				WHERE	F.ResourceBk IN ('a1X8e000001foz4EAA', 'a1X4K000000K8xfUAC' ) */
			) , cteIdentifyIslandsOfAbsences
			AS(
				SELECT	F.* 
						,Islands = RN-Gaps
				FROM	cteIdentifyGaps F
				WHERE	F.IsAbsence = 1
			)
			INSERT INTO Internal.ResourceAbsence
			( 
				 ResourceBk
				,AbsenceStartDate
				,AbsenceEndDate
				,NumberOfDays

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT	
				 I.ResourceBk 
				,AbsenceStartDate	= MIN(I.AbsenceDate)
				,AbsenceEndDate		= MAX(I.AbsenceDate)
				,NumberOfDays		= SUM(I.HolidayHours/8) 
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM	cteIdentifyIslandsOfAbsences I 
			GROUP BY I.ResourceBk , I.Islands ;


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #ResourceAbsence S ;
			SELECT @strOldWatermark	= CONVERT(VARCHAR(35),@_Watermark,121);


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