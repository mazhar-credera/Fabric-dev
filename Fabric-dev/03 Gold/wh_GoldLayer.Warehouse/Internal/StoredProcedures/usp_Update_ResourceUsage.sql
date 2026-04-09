CREATE  
	PROCEDURE Internal.usp_Update_ResourceUsage
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 

AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceUsage]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceUsage]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceUsage]')
	EXEC Internal.usp_Update_ResourceUsage @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM Internal.ResourceUsage ; -- 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);


	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Src ;

			SELECT	 ResourceBk				= PA.KimbleOne__Resource__c 
					,PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) 
					,PeriodEndDate			= CAST(TP.KimbleOne__EndDate__c AS DATE) 
					,PerformanceAnalysisBk	= PA.Id 
					,AccountBk				= PA.KimbleOne__Account__c 
					,ResourcedActivityTypeBk= RA.KimbleOne__ResourcedActivityType__c 
					,AnalysisFactBk			= PA.KimbleOne__AnalysisFact__c
					,DeliveryGroupBk		= PA.KimbleOne__DeliveryGroup__c
					,DmwActivityType				= RA.KC_DMW_Activity_Type__c 
					,ResourcedActivityDisplayName	= RA.DisplayName__c 
					,PaBusinessUnitBk		= PA.KimbleOne__BusinessUnit__c

					,DeliveryElementBk		= PA.KimbleOne__DeliveryElement__c
					,PracticeBk				= RH.Practice__c 
					,GradeBk				= RH.KimbleOne__Grade__c

					,AccountBusinessUnitBk	= AC.KimbleOne__BusinessUnit__c 
					,ResourceBusinessUnitBk	= RH.KimbleOne__BusinessUnit__c 

					,P1ForecastAmount		= ISNULL(PA.KimbleOne__P1ForecastAmount__c, 0)	
					,P2ForecastAmount		= ISNULL(PA.KimbleOne__P2ForecastAmount__c, 0)	
					,P3ForecastAmount		= ISNULL(PA.KimbleOne__P3ForecastAmount__c, 0)	

					,PA._crda_ActiveFromDateTime 

			INTO #Src 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																		AND	TP._crda_isDeleted			= 0 
																		AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																		AND PT._crda_isDeleted			= 0
																		AND	PT.[Name]					= 'Month'
																		AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id						= PA.KimbleOne__ResourcedActivity__c
																				AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																				AND	RA._crda_isDeleted			= 0

			INNER JOIN lh_SilverLayer.Kantata.HISTORY_Resource		RO	ON	RO.Id						= PA.KimbleOne__Resource__c 
																		AND	RO._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																		AND	RO._crda_isDeleted			= 0

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcePeriod	RP	ON	RP.Id					= PA.KimbleOne__ResourcePeriod__c 
																			AND	RP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	RP._crda_isDeleted			= 0

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourceHistory	RH	ON	RH.Id						= RP.KimbleOne__ResourceHistory__c 
																			AND	RH._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	RH._crda_isDeleted			= 0


			LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Account	AC	ON	AC.Id						= PA.KimbleOne__Account__c 
																	AND	AC._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																	AND	AC._crda_isDeleted			= 0

			WHERE	PA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
					/* Filter just ResourceUsage Records */
			AND		PA.KimbleOne__AnalysisFact__c	IN	('a0ED000000CxJIzMAN',  /*ResourceUsage*/ 
														 'a0ED000000CxJJ0MAN')	/*FactoredResourceUsage*/ 
			AND		PA._crda_isDeleted = 0
			AND		PA._crda_ActiveFromDateTime >= @_Watermark 


			DELETE	T 
			FROM	Internal.ResourceUsage	T
			INNER JOIN #Src	S	ON	S.ResourceBk		= T.ResourceBk
								AND	S.PeriodStartDate	= T.PeriodStartDate 
								AND	S.PeriodEndDate		= T.PeriodEndDate ; 


			TRUNCATE TABLE Internal.ResourceUsage ; 

			INSERT INTO Internal.ResourceUsage
			( 
					 [ResourceBk]
					,[PeriodStartDate]
					,[PeriodEndDate]
					,PerformanceAnalysisBk
					,[AccountBk]
					,[AnalysisFactBk]
					,[ResourcedActivityTypeBk]
					,[DeliveryGroupBk]
					,[DeliveryElementBk]
					,DmwActivityType 
					,ResourcedActivityDisplayName 
					,[PaBusinessUnitBk]

					,[PracticeBk]
					,[GradeBk]
					,[AccountBusinessUnitBk]
					,[ResourceBusinessUnitBk]
					,[P1ForecastAmount]
					,[P2ForecastAmount]
					,[P3ForecastAmount]

					,_crda_ActiveFromDateTime
					,_crda_CreatedExecutionId
					,_crda_CreatedDateTime
				)
				SELECT  
					 SRC.[ResourceBk]
					,SRC.[PeriodStartDate]
					,SRC.[PeriodEndDate]
					,SRC.PerformanceAnalysisBk 
					,SRC.[AccountBk]
					,SRC.[AnalysisFactBk]
					,SRC.[ResourcedActivityTypeBk]
					,SRC.[DeliveryGroupBk]
					,SRC.[DeliveryElementBk]
					,SRC.DmwActivityType 
					,SRC.ResourcedActivityDisplayName 
					,SRC.[PaBusinessUnitBk]

					,SRC.[PracticeBk]
					,SRC.[GradeBk]
					,SRC.[AccountBusinessUnitBk]
					,SRC.[ResourceBusinessUnitBk]
					,SRC.[P1ForecastAmount]
					,SRC.[P2ForecastAmount]
					,SRC.[P3ForecastAmount]

					,SRC._crda_ActiveFromDateTime
					,@_ExecutionId 
					,GETUTCDATE() 
				FROM	#Src SRC
				ORDER BY
					 SRC.[ResourceBk]
					,SRC.[PeriodStartDate] ; 


			/*PK/Unique constraints are not enforced so...*/
			;WITH cteDups
			AS( 
				SELECT	 ResourceBk, PeriodStartDate,PerformanceAnalysisBk 
						,RN =	ROW_NUMBER() 
								OVER (
									PARTITION BY	ResourceBk, PeriodStartDate,PerformanceAnalysisBk 
									ORDER BY		ResourceBk, PeriodStartDate 
								)
				FROM	Internal.ResourceUsage T
			) 
			DELETE FROM cteDups WHERE RN > 1 ;

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