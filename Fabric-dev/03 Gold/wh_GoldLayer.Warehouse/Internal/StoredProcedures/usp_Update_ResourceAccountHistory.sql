CREATE  
	PROCEDURE Internal.usp_Update_ResourceAccountHistory
	--Default Parameters
	@ExecutionId	INT ,
	@Watermark		VARCHAR(255), 
	@ProcessId		INT 

AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceAccountHistory]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceAccountHistory]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceAccountHistory]')
	--DECLARE @LastExecId INT = (SELECT MAX(LastExecutionId) FROM FabricDb.ETL.ProcessMap);
	EXEC Internal.usp_Update_ResourceAccountHistory @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId 
	SELECT * FROM Internal.ResourceAccountHistory ; 
	SELECT COUNT(1) FROM [Internal].[ResourceAccountHistory] ; --660431
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	DECLARE @_ExecutionId	INT		= @ExecutionId, 
			@_Watermark		DATETIME2= CONVERT(DATETIME2, @Watermark),
			@_ProcessId		INT		 = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35) =CONVERT(VARCHAR(35),@_Watermark,121),
			@_PaWatermark		DATETIME2= CONVERT(DATETIME2, '20000101'); /*GroundhogDay Load*/


	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #ResourceAccountHistory;

			SELECT 
				 X.PerformanceAnalysisBk
				,X.ResourceBk	
				,X.TimePeriodBk	
				,X.AccountBk	
				,X.PeriodStartDate
				,X.PeriodEndDate	
				,PeriodStartDateSk	= (CONVERT([int],CONVERT([varchar](8),X.PeriodStartDate,(112))))
				,PeriodEndDateSk	= (CONVERT([int],CONVERT([varchar](8),X.PeriodEndDate,(112))))	
						
				/*ForecastRevenue*/
				,X.P1ForecastRevenue
				,X.P2ForecastRevenue
				,X.P3ForecastRevenue

				/*ResourceUsage*/
				,X.P1ForecastResourceUsageDelivery
				,X.P2ForecastResourceUsageDelivery
				,X.P3ForecastResourceUsageDelivery

				/*FactoredResourceUsage*/	
				,X.FactoredP1ForecastResourceUsageDelivery
				,X.FactoredP2ForecastResourceUsageDelivery
				,X.FactoredP3ForecastResourceUsageDelivery

				,X.RecordType 
				,X._crda_ActiveFromDateTime

			INTO #ResourceAccountHistory 
			FROM
			(
				SELECT	 
					 PerformanceAnalysisBk	= PA.Id 
					,ResourceBk				= PA.KimbleOne__Resource__c 
					,TimePeriodBk			= PA.KimbleOne__TimePeriod__c 
					,AccountBk				= ISNULL(PA.KimbleOne__Account__c , 'UnknownRecord') 
					,PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) 
					,PeriodEndDate			= CAST(TP.KimbleOne__EndDate__c AS DATE) 

													/*ForecastRevenue*/
					,P1ForecastRevenue		= NULL 
					,P2ForecastRevenue		= NULL 
					,P3ForecastRevenue		= NULL 

													/*ResourceUsage*/
					,P1ForecastResourceUsageDelivery	= IIF(AF.Id = 'a0ED000000CxJIzMAN', PA.KimbleOne__P1ForecastResourceUsageDelivery__c, 0 ) 
					,P2ForecastResourceUsageDelivery	= IIF(AF.Id = 'a0ED000000CxJIzMAN', PA.KimbleOne__P2ForecastResourceUsageDelivery__c, 0 )  
					,P3ForecastResourceUsageDelivery	= IIF(AF.Id = 'a0ED000000CxJIzMAN', PA.KimbleOne__P3ForecastResourceUsageDelivery__c, 0 )  
					
													/*FactoredResourceUsage*/	
					,FactoredP1ForecastResourceUsageDelivery	= IIF(AF.Id = 'a0ED000000CxJJ0MAN', PA.KimbleOne__P1ForecastResourceUsageDelivery__c, 0 ) 
					,FactoredP2ForecastResourceUsageDelivery	= IIF(AF.Id = 'a0ED000000CxJJ0MAN', PA.KimbleOne__P2ForecastResourceUsageDelivery__c, 0 )  
					,FactoredP3ForecastResourceUsageDelivery	= IIF(AF.Id = 'a0ED000000CxJJ0MAN', PA.KimbleOne__P3ForecastResourceUsageDelivery__c, 0 ) 

					,RecordType	= 'ResourceDelivUsage' 
					,PA._crda_ActiveFromDateTime 

				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA 

				INNER JOIN lh_SilverLayer.Kantata.HISTORY_AnalysisFact	AF	ON	AF.Id = PA.KimbleOne__AnalysisFact__c 
																			AND	AF.Id IN (	/*'ResourceUsage', 'FactoredResourceUsage'*/
																							'a0ED000000CxJIzMAN', 'a0ED000000CxJJ0MAN'
																						 ) 
																			AND	AF._crda_isDeleted			= 0 
																			AND	AF._crda_ActiveToDateTime = '9999-12-31 23:59:59'

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																			AND	TP._crda_isDeleted			= 0 
																			AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																			AND PT._crda_isDeleted			= 0
																			AND	PT.[Name]					= 'Month'
																			AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				WHERE	PA._crda_isDeleted			= 0 
				AND		PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				AND		PA._crda_ActiveFromDateTime >= @_PaWatermark 
				AND		PA.KimbleOne__Resource__c	IS NOT NULL 

				UNION ALL 

				SELECT	 
					 PerformanceAnalysisBk	= PA.Id 
					,ResourceBk				= PA.KimbleOne__Resource__c 
					,TimePeriodBk			= PA.KimbleOne__TimePeriod__c  
					,AccountBk				= ISNULL(PA.KimbleOne__Account__c , 'UnknownRecord') 
					,PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE)  
					,PeriodEndDate			= CAST(TP.KimbleOne__EndDate__c AS DATE)  

													/*ForecastRevenue*/
					,P1ForecastRevenue		= PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc  
					,P2ForecastRevenue		= PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc  
					,P3ForecastRevenue		= PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc 

													/*ResourceUsage*/
					,P1ForecastResourceUsageDelivery			= NULL
					,P2ForecastResourceUsageDelivery			= NULL
					,P3ForecastResourceUsageDelivery			= NULL

													/*FactoredResourceUsage*/
					,FactoredP1ForecastResourceUsageDelivery	= NULL 
					,FactoredP2ForecastResourceUsageDelivery	= NULL 
					,FactoredP3ForecastResourceUsageDelivery	= NULL 

					,RecordType	= 'ForecastRevenue' 
					,PA._crda_ActiveFromDateTime 

				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA 

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																					AND	TP._crda_isDeleted			= 0 
																					AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																					AND PT._crda_isDeleted			= 0
																					AND	PT.[Name]					= 'Month'
																					AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

				WHERE	PA._crda_isDeleted			= 0 
				AND		PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				AND		PA._crda_ActiveFromDateTime >= @_PaWatermark 
				AND		PA.KimbleOne__Resource__c	IS NOT NULL  
				AND		PA.KimbleOne__AnalysisFact__c	IN ('a0E3z00000uZEf6EAG',	/*RevenueInternal*/
															'a0E3z00000uZEf7EAG',	/*CostInternal	 */
															'a0ED000000CxJIuMAN',	/*Revenue		 */
															'a0ED000000CxJIvMAN')	/*Cost			 */
			) X	;


			TRUNCATE TABLE Internal.ResourceAccountHistory ;

			INSERT INTO Internal.ResourceAccountHistory
			( 
				 PerformanceAnalysisBk
				,ResourceBk
				,AccountBk
				,TimePeriodBk
				,PeriodStartDate
				,PeriodEndDate
				,PeriodStartDateSk 
				,PeriodEndDateSk 

				,P1ForecastResourceUsageDelivery
				,P2ForecastResourceUsageDelivery
				,P3ForecastResourceUsageDelivery

				,FactoredP1ForecastResourceUsageDelivery
				,FactoredP2ForecastResourceUsageDelivery
				,FactoredP3ForecastResourceUsageDelivery

				,P1ForecastRevenue
				,P2ForecastRevenue
				,P3ForecastRevenue
				,RecordType

				,_crda_CreatedExecutionId 
				,_crda_CreatedDateTime 
			)
			SELECT  
				 SRC.PerformanceAnalysisBk
				,SRC.ResourceBk
				,SRC.AccountBk
				,SRC.TimePeriodBk
				,SRC.PeriodStartDate
				,SRC.PeriodEndDate
				,SRC.PeriodStartDateSk 
				,SRC.PeriodEndDateSk 

				,SRC.P1ForecastResourceUsageDelivery
				,SRC.P2ForecastResourceUsageDelivery
				,SRC.P3ForecastResourceUsageDelivery

				,SRC.FactoredP1ForecastResourceUsageDelivery
				,SRC.FactoredP2ForecastResourceUsageDelivery
				,SRC.FactoredP3ForecastResourceUsageDelivery

				,SRC.P1ForecastRevenue
				,SRC.P2ForecastRevenue
				,SRC.P3ForecastRevenue
				,SRC.RecordType

				,@_ExecutionId  
				,GETUTCDATE() 
			FROM	#ResourceAccountHistory	SRC 
			/*SELECT new01=@@ROWCOUNT;*/


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #ResourceAccountHistory S ;

			SELECT	InitialWatermark	= @strOldWatermark, 
					UpdatedWatermark	= @strNewWatermark ; 

		COMMIT;

	END TRY
	BEGIN CATCH
		ROLLBACK;
		IF @@TRANCOUNT > 0 ROLLBACK; 
		THROW;
	END CATCH ; 

	IF @@TRANCOUNT > 0 ROLLBACK; 

END;