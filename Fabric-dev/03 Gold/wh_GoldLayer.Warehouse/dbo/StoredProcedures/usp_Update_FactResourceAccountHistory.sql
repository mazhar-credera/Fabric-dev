CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactResourceAccountHistory
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , --not used
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	GroundhogDay Load 

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceAccountHistory]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceAccountHistory]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceAccountHistory]')
	EXEC dbo.usp_Update_FactResourceAccountHistory @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId 
	--SELECT * FROM [dbo].[FactResourceAccountHistory] ; 
	SELECT COUNT(1) FROM [dbo].[FactResourceAccountHistory] ; --112897
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters 
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 


	-- GroundhogDay Load
	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35) =CONVERT(VARCHAR(35),@_Watermark,121),
			@_PaWatermark		DATETIME2= CONVERT(DATETIME2, '20000101'); 

	DECLARE @TimeNow	DATETIME2= GETUTCDATE() ;
	DECLARE	@FutureDate	DATE = DATEADD(YEAR, 3, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #ResourceAndAccounts ;
			DROP TABLE IF EXISTS #ResourceDelivUsage;
			DROP TABLE IF EXISTS #ForecastRevenue;


			SELECT
				 RAD.ResourceSk 
				,RAD.ResourceBk 
				,RAD.PeriodStart
				,RAD.PeriodEnd 
				,AccountBk	= ISNULL(X.AccountBk , 'UnknownRecord')
				,AccountSk	= ISNULL(X.AccountSk, -1) 
				,_crda_ActiveFromDateTime
			INTO #ResourceAndAccounts 
			FROM  dbo.FN_GetResourceAllDates (@FutureDate)	RAD
			LEFT JOIN (
				SELECT	ResourceBk		= PA.KimbleOne__Resource__c , 
						DR.ResourceSk , 
						PeriodStart		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEnd		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						AccountBk		= ISNULL(PA.KimbleOne__Account__c , 'UnknownRecord') ,
						AccountSk		= ISNULL(AC.AccountSk, -1) , 
						_crda_ActiveFromDateTime	= MAX(PA._crda_ActiveFromDateTime)
				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA 
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																	AND	TP._crda_isDeleted			= 0  
																	AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																	AND PT._crda_isDeleted			= 0 
																	AND	PT.[Name]					= 'Month'
																	AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	dbo.DimResource						DR	ON	DR.ResourceBk				= PA.KimbleOne__Resource__c 
																	AND	DR.IsCurrent				= 1 
				LEFT JOIN	dbo.DimAccount						AC	ON	AC.AccountBk				= PA.KimbleOne__Account__c 
																	AND	AC.IsCurrent				= 1 

				WHERE	PA._crda_isDeleted = 0 
				AND		PA._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
				AND		PA._crda_ActiveFromDateTime >= @_PaWatermark 

				GROUP BY	PA.KimbleOne__Resource__c, 
							DR.ResourceSk ,
							CAST(TP.KimbleOne__StartDate__c AS DATE) ,
							CAST(TP.KimbleOne__EndDate__c AS DATE) ,
							ISNULL(PA.KimbleOne__Account__c , 'UnknownRecord') , 
							ISNULL(AC.AccountSk, -1) 
			) X		ON	X.ResourceSk	= RAD.ResourceSk 
					AND	X.PeriodStart	= RAD.PeriodStart
					AND X.PeriodEnd		= RAD.PeriodEnd 

			/*
				Get Delivery ResourceUsage and ForecastResourceUsage 
			*/
			SELECT	  ResourceBk	= PA.ResourceBk 
					, AccountBk		= PA.AccountBk  
					, PeriodStart	= PA.PeriodStartDate 
					, PeriodEnd		= PA.PeriodEndDate 

					, P1ForecastResourceUsageDelivery	= SUM(ISNULL(PA.P1ForecastResourceUsageDelivery, 0 ) ) 
					, P2ForecastResourceUsageDelivery	= SUM(ISNULL(PA.P2ForecastResourceUsageDelivery, 0 ) ) 
					, P3ForecastResourceUsageDelivery	= SUM(ISNULL(PA.P3ForecastResourceUsageDelivery, 0 ) ) 
					
					, FactoredP1ForecastResourceUsageDelivery	= SUM(ISNULL(PA.FactoredP1ForecastResourceUsageDelivery, 0 ) )  
					, FactoredP2ForecastResourceUsageDelivery	= SUM(ISNULL(PA.FactoredP2ForecastResourceUsageDelivery, 0 ) )  
					, FactoredP3ForecastResourceUsageDelivery	= SUM(ISNULL(PA.FactoredP3ForecastResourceUsageDelivery, 0 ) ) 

			INTO #ResourceDelivUsage
			FROM	internal.ResourceAccountHistory	PA 
			WHERE	PA.RecordType = 'ResourceDelivUsage' 
			GROUP BY	  PA.ResourceBk
						, PA.AccountBk 
						, PA.PeriodStartDate 
						, PA.PeriodEndDate 


			/*
				Get #ForecastRevenue 
			*/
			SELECT	  ResourceBk	= PA.ResourceBk 
					, AccountBk		= PA.AccountBk  
					, PeriodStart	= PA.PeriodStartDate 
					, PeriodEnd		= PA.PeriodEndDate 

					, P1ForecastRevenue	= SUM(ISNULL(PA.P1ForecastRevenue, 0) ) 
					, P2ForecastRevenue	= SUM(ISNULL(PA.P2ForecastRevenue, 0) )  
					, P3ForecastRevenue	= SUM(ISNULL(PA.P3ForecastRevenue, 0) ) 

			INTO #ForecastRevenue
			FROM	internal.ResourceAccountHistory	PA 
			WHERE	PA.RecordType = 'ForecastRevenue' 
			GROUP BY	  PA.ResourceBk
						, PA.AccountBk 
						, PA.PeriodStartDate 
						, PA.PeriodEndDate 



			TRUNCATE TABLE dbo.FactResourceAccountHistory ;

			INSERT INTO dbo.FactResourceAccountHistory( 
					 ResourceSk
					,AccountSk
					,PeriodStart
					,PeriodEnd

					,P1ForecastResourceUsageDelivery
					,P2ForecastResourceUsageDelivery
					,P3ForecastResourceUsageDelivery

					,FactoredP1ForecastResourceUsageDelivery
					,FactoredP2ForecastResourceUsageDelivery
					,FactoredP3ForecastResourceUsageDelivery

					,P1ForecastRevenue
					,P2ForecastRevenue
					,P3ForecastRevenue

					,_crda_CreatedExecutionId
					,_crda_CreatedDateTime
				)
			SELECT
					 RA.ResourceSk	
					,RA.AccountSk	
					,RA.PeriodStart 
					,RA.PeriodEnd 

					,ISNULL(RD.P1ForecastResourceUsageDelivery, 0 ) 
					,ISNULL(RD.P2ForecastResourceUsageDelivery, 0 ) 
					,ISNULL(RD.P3ForecastResourceUsageDelivery, 0 ) 

					,ISNULL(RD.FactoredP1ForecastResourceUsageDelivery, 0 ) 
					,ISNULL(RD.FactoredP2ForecastResourceUsageDelivery, 0 ) 
					,ISNULL(RD.FactoredP3ForecastResourceUsageDelivery, 0 ) 

					,ISNULL(FR.P1ForecastRevenue, 0 ) 
					,ISNULL(FR.P2ForecastRevenue, 0 ) 
					,ISNULL(FR.P3ForecastRevenue, 0 ) 

					,@_ExecutionId 
					,GETUTCDATE() 
			FROM
				#ResourceAndAccounts		RA 

			LEFT JOIN	
				#ResourceDelivUsage			RD	ON	RD.ResourceBk		= RA.ResourceBk 
												AND	RD.AccountBk		= RA.AccountBk 
												AND	RD.PeriodStart		= RA.PeriodStart 
												AND	RD.PeriodEnd		= RA.PeriodEnd 
			LEFT JOIN	
				#ForecastRevenue			FR	ON	FR.ResourceBk		= RA.ResourceBk 
												AND	FR.AccountBk		= RA.AccountBk 
												AND	FR.PeriodStart		= RA.PeriodStart 
												AND	FR.PeriodEnd		= RA.PeriodEnd 

			--WHERE	RA.AccountSk > 0 
			ORDER BY
					RA.ResourceBk , 
					RA.AccountBk ,
					RA.PeriodStart ;


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #ResourceAndAccounts S ;

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