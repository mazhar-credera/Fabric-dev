CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactResourceAnalysis
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	GroundhogDay Load 

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceAnalysis]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceAnalysis]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceAnalysis]')
	EXEC dbo.usp_Update_FactResourceAnalysis @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId 
	SELECT * FROM [dbo].[FactResourceAnalysis] ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters 
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) ,
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);
	BEGIN TRY

		BEGIN TRANSACTION 

			TRUNCATE TABLE dbo.FactResourceAnalysis ;

			DROP TABLE IF EXISTS #P1OtherUsage ;
			DROP TABLE IF EXISTS #Holidays ; 
			DROP TABLE IF EXISTS #ResourceUsage ; 
			DROP TABLE IF EXISTS #ResourcePracticeHistory ;
			DROP TABLE IF EXISTS #Source ; 

			/*
				Get P1 "Other" Usage by Resource 
			*/
			;WITH cteP1OtherUsage
			AS (
				SELECT		 TimePeriodBk			= TP.KimbleOne__ForecastingTimePeriod__c	
							,PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) 
							,PeriodEndDate			= CAST(TP.KimbleOne__EndDate__c AS DATE) 
							,ResourceBk				= APA.KimbleOne__Resource__c 
							,ResourcedActivityBk	= RA.Id	
							,P1UsageOtherSales		= IIF(RA.[Name] LIKE 'SALES >%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherHoliday	= IIF(RA.[Name] LIKE 'Absence > Holiday%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherAbsence	= IIF(RA.[Name] LIKE 'Absence >%' AND RA.[Name] NOT LIKE 'Absence > Holiday%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherDMWApps	= IIF(RA.[Name] LIKE 'DMW Apps >%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherPeople		= IIF(RA.[Name] LIKE 'People >%'  AND RA.[Name] NOT LIKE 'People > Training%', APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherTraining	= IIF(RA.[Name] LIKE 'People > Training%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherStrategy	= IIF(RA.[Name] LIKE 'Strategy >%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherSupport	= IIF(RA.[Name] LIKE 'Support >%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherTech		= IIF(RA.[Name] LIKE 'Technology >%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,P1UsageOtherDelivery	= IIF(RA.[Name] LIKE 'Delivery >%',  APA.KimbleOne__ForecastP1Usage__c,  0 ) 
							,ForecastP1Usage		= ISNULL(APA.KimbleOne__ForecastP1Usage__c, 0) 
				FROM		lh_SilverLayer.Kantata.HISTORY_ActivityPeriodAssignment APA  

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment		AA 	ON	AA.Id						= APA.KimbleOne__ActivityAssignment__c 
																		AND	AA._crda_isDeleted			= 0  
																		AND	AA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity		RA  ON	RA.Id						= AA.KimbleOne__ResourcedActivity__c 
																		AND	RA._crda_isDeleted			= 0  
																		AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivityType	RT  ON	RT.Id						= RA.KimbleOne__ResourcedActivityType__c 
																		AND RT._crda_isDeleted			= 0  
																		AND	RT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																		AND	RT.[Name]					= 'Other' 
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod				TP 	ON  TP.Id						= APA.KimbleOne__TimePeriod__c 
																		AND	TP._crda_isDeleted			= 0  
																		AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType				PT	ON	PT.Id				= TP.KimbleOne__PeriodType__c 
																		AND PT._crda_isDeleted	= 0 
																		AND	PT.[Name]			= 'Month'
																		AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				WHERE	APA._crda_isDeleted = 0 
				AND		APA._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
				AND		APA._crda_ActiveFromDateTime >= @_Watermark 
				AND		APA.KimbleOne__Resource__c IS NOT NULL 
			)
			SELECT	P.TimePeriodBk , 
					P.PeriodStartDate , 
					P.PeriodEndDate ,
					P.ResourceBk , 
					P1UsageOtherSales	= SUM(P1UsageOtherSales) , 
					P1UsageOtherHoliday	= SUM(P1UsageOtherHoliday) , 
					P1UsageOtherAbsence	= SUM(P1UsageOtherAbsence) , 
					P1UsageOtherDMWApps	= SUM(P1UsageOtherDMWApps) , 
					P1UsageOtherPeople	= SUM(P1UsageOtherPeople) , 
					P1UsageOtherTraining= SUM(P1UsageOtherTraining) , 
					P1UsageOtherStrategy= SUM(P1UsageOtherStrategy) , 
					P1UsageOtherSupport	= SUM(P1UsageOtherSupport) , 
					P1UsageOtherTech	= SUM(P1UsageOtherTech) , 
					P1UsageOtherDelivery= SUM(P1UsageOtherDelivery) , 
					P1Other				= SUM(ForecastP1Usage) - (	SUM(P1UsageOtherSales)   + 
																	SUM(P1UsageOtherHoliday) + 
																	SUM(P1UsageOtherAbsence) + 
																	SUM(P1UsageOtherDMWApps) +  
																	SUM(P1UsageOtherPeople)  + 
																	SUM(P1UsageOtherTraining) +  
																	SUM(P1UsageOtherStrategy) + 
																	SUM(P1UsageOtherSupport) + 
																	SUM(P1UsageOtherTech)    + 
																	SUM(P1UsageOtherDelivery)
																)

			INTO #P1OtherUsage 
			FROM		cteP1OtherUsage	P 
			GROUP BY	 P.TimePeriodBk  
						,P.PeriodStartDate 
						,P.PeriodEndDate 
						,P.ResourceBk ;


			/*
				Get Hoildays Booked/Planned Per Resource  
			*/
			SELECT		PeriodStartDate		= CAST(CP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate		= CAST(CP.KimbleOne__EndDate__c AS DATE) , 
						ResourceBk			= FTE.KimbleOne__Resource__c ,
						HolidayHours		= SUM(FTE.KimbleOne__EntryUnits__c) , 
						HolidayDays			= SUM(FTE.KimbleOne__EntryUnits__c)/8  
			INTO #Holidays 
			FROM		lh_SilverLayer.Kantata.HISTORY_ForecastTimeEntry	FTE  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment	AA 	ON	AA.Id				= FTE.KimbleOne__ActivityAssignment__c 
																AND AA._crda_isDeleted	= 0  
																AND	AA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																AND	AA.IsHoliday = 1
											
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON	TP.Id				= FTE.KimbleOne__TimePeriod__c
																AND TP._crda_isDeleted	= 0 
																AND	TP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			CP 	ON	CP.Id				= TP.KimbleOne__ForecastingTimePeriod__c
																AND CP._crda_isDeleted	= 0 
																AND	CP._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id				= CP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted	= 0 
																AND	PT.[Name]			= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			WHERE		FTE._crda_isDeleted			= 0  
			AND			FTE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'   
			AND			FTE._crda_ActiveFromDateTime >= @_Watermark 
			AND			FTE.KimbleOne__Resource__c IS NOT NULL 
			GROUP BY	FTE.KimbleOne__Resource__c ,
						CAST(CP.KimbleOne__StartDate__c AS DATE) ,
						CAST(CP.KimbleOne__EndDate__c AS DATE) ;


			/*
				Get Forecast / Actual Per Resource  
			*/
			SELECT		 ResourceBk				= RP.KimbleOne__Resource__c
						,TimePeriodBk			= RP.KimbleOne__TimePeriod__c
						,PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) 
						,PeriodEndDate			= CAST(TP.KimbleOne__EndDate__c AS DATE) 
						,ActualUsage						= RP.KimbleOne__ActualUsage__c
						,ForecastP1TrackedUsage				= RP.KimbleOne__ForecastP1TrackedUsage__c
						,ForecastP1UtilisationIncludedUsage	= RP.KimbleOne__ForecastP1UtilisationIncludedUsage__c 
			INTO #ResourceUsage  
			FROM		lh_SilverLayer.Kantata.HISTORY_ResourcePeriod	RP

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod		TP	ON	RP.KimbleOne__TimePeriod__c = TP.Id
															AND TP._crda_isDeleted = 0 
															AND	TP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType		PT	ON	PT.Id		= TP.KimbleOne__PeriodType__c
															AND PT._crda_isDeleted	= 0  
															AND	PT._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
															AND	PT.[Name]			= 'Month'
			WHERE		RP._crda_isDeleted			= 0  
			AND			RP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'   
			AND			RP._crda_ActiveFromDateTime >= @_Watermark 
			AND			RP.KimbleOne__Resource__c	IS NOT NULL ;


			/*
				Capture movements of Resources between Practices
				This is stored in HISTORY_ResourceHistory
				Query uses Gaps/Islands to correctly record movements 
				of Resources leaving and returning back to the same practice later
			*/
			SELECT	Y.ResourceBk , 
					Y.PracticeBk , 
					EffectiveFromDate	= MIN(Y.EffectiveFromDate) 
					,EffectiveToDate		= LEAD(DATEADD(MILLISECOND, -3, MIN(Y.EffectiveFromDate)), 1, '99991231')	
												OVER(
													PARTITION BY	Y.ResourceBk
													ORDER BY		MIN(Y.EffectiveFromDate)
												)
			INTO #ResourcePracticeHistory 
			FROM ( 
				SELECT	X.ResourceBk, 
						X.PracticeBk, 
						X.EffectiveFromDate , 
						Islands = RN - Gaps
				FROM (
					SELECT	ResourceBk		= RH.KimbleOne__Resource__c, 
							PracticeBk		= RH.Practice__c, 
							EffectiveFromDate= RH.KimbleOne__EffectiveDate__c ,
							RN = ROW_NUMBER()
									OVER(
										PARTITION BY RH.KimbleOne__Resource__c 
										ORDER BY	RH.KimbleOne__EffectiveDate__c
									) , 
							Gaps = ROW_NUMBER()
									OVER(
										PARTITION BY RH.KimbleOne__Resource__c , RH.Practice__c
										ORDER BY	RH.KimbleOne__EffectiveDate__c
									)
					FROM	lh_SilverLayer.Kantata.HISTORY_ResourceHistory	RH
					WHERE	RH._crda_isDeleted = 0 
					AND		RH._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
					--AND		RH.KimbleOne__Resource__c = 'a1X4K000000JV5hUAG'
				) X
			) Y 
			GROUP BY 
				Y.ResourceBk , 
				Y.PracticeBk , 
				Y.Islands 
			ORDER BY Y.ResourceBk, EffectiveFromDate ;


			/*
				Get Targets for DeliveryUtilisationPctTgt by Resource 
			*/
			SELECT	DeliveryUtilisationPctTgt	= PA.KimbleOne__TargetAmount__c  , 
					PeriodStartDate				= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate				= CAST(TP.KimbleOne__EndDate__c AS DATE) , 
					ResourceBk					= PA.KimbleOne__Resource__c 
			INTO #DelivUtilRsrcTgt
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_AnalysisFact			AF	ON	AF.Id = PA.KimbleOne__AnalysisFact__c 
																AND	AF.[Name] = 'DeliveryUtilisationPct'
																AND	AF._crda_isDeleted = 0 
																AND	AF._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_AnalysisDimension		AD	ON	AD.Id = PA.KimbleOne__AnalysisDimension__c 
																AND	AD.[Name] = 'Resource'
																AND	AD._crda_isDeleted = 0 
																AND	AD._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id				= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted	= 0 
																AND	PT.[Name]			= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			WHERE	PA._crda_isDeleted = 0 
			AND		PA._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime >= @_Watermark ;


			SELECT	 ResourceBk				= RA.KimbleOne__Resource__c 
					,PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) 
					,PeriodEndDate			= CAST(TP.KimbleOne__EndDate__c AS DATE) 
					,RA._crda_ActiveFromDateTime, RA._crda_ActiveToDateTime
					,ResourceBusinessUnitBk	= RA.KimbleOne__BusinessUnit__c 
					,ResourcePracticeBk		= RPH.PracticeBk 
					,GradeBk				= RA.KimbleOne__Grade__c 
					,RA.CurrencyIsoCode 
					,FTE						= RA.FTE__c

					,P1AvailableDays			= ISNULL(RA.P1AvailableDays__c , 0 ) 
					,P1DeliveryUtilisationDays	= ISNULL(RA.KimbleOne__P1DeliveryUtilisationDays__c , 0 ) 
					,P1SalesUtilisationDays		= ISNULL(RA.KimbleOne__P1SalesUtilisationDays__c , 0 ) 
					,P1OtherUtilisationDays		= ISNULL(RA.KimbleOne__P1OtherUtilisationDays__c , 0 ) 
					,P1AverageCostRate			= ISNULL(RA.KimbleOne__P1AverageCostRate__c , 0 ) 
					,P1AverageRevenueRate		= ISNULL(RA.KimbleOne__P1AverageRevenueRate__c  , 0 ) 
					,P1Cost						= ISNULL(RA.KimbleOne__P1Cost__c , 0 ) 
					,P1ExpensesCost				= ISNULL(RA.KimbleOne__P1ExpensesCost__c  , 0 ) 
					,P1ExpensesRevenue			= ISNULL(RA.KimbleOne__P1ExpensesRevenue__c  , 0 ) 
					,P1Revenue					= ISNULL(RA.KimbleOne__P1Revenue__c  , 0 ) 
					,P1ServicesCost				= ISNULL(RA.KimbleOne__P1ServicesCost__c  , 0 ) 
					,P1ServicesRevenue			= ISNULL(RA.KimbleOne__P1ServicesRevenue__c , 0 ) 

					,P2AvailableDays			= ISNULL(RA.P2AvailableDays__c , 0 ) 
					,P2DeliveryUtilisationDays	= ISNULL(RA.KimbleOne__P2DeliveryUtilisationDays__c , 0 ) 
					,P2SalesUtilisationDays		= ISNULL(RA.KimbleOne__P2SalesUtilisationDays__c , 0 ) 
					,P2OtherUtilisationDays		= ISNULL(RA.KimbleOne__P2OtherUtilisationDays__c , 0 ) 
					,P2AverageCostRate			= ISNULL(RA.KimbleOne__P2AverageCostRate__c , 0 ) 
					,P2AverageRevenueRate		= ISNULL(RA.KimbleOne__P2AverageRevenueRate__c  , 0 ) 
					,P2Cost						= ISNULL(RA.KimbleOne__P2Cost__c , 0 ) 
					,P2ExpensesCost				= ISNULL(RA.KimbleOne__P2ExpensesCost__c  , 0 ) 
					,P2ExpensesRevenue			= ISNULL(RA.KimbleOne__P2ExpensesRevenue__c  , 0 ) 
					,P2Revenue					= ISNULL(RA.KimbleOne__P2Revenue__c  , 0 ) 
					,P2ServicesCost				= ISNULL(RA.KimbleOne__P2ServicesCost__c  , 0 ) 
					,P2ServicesRevenue			= ISNULL(RA.KimbleOne__P2ServicesRevenue__c , 0 ) 

					,P3AvailableDays			= ISNULL(RA.P3AvailableDays__c , 0 ) 
					,P3DeliveryUtilisationDays	= ISNULL(RA.KimbleOne__P3DeliveryUtilisationDays__c , 0 ) 
					,P3SalesUtilisationDays		= ISNULL(RA.KimbleOne__P3SalesUtilisationDays__c , 0 ) 
					,P3OtherUtilisationDays		= ISNULL(RA.KimbleOne__P3OtherUtilisationDays__c , 0 ) 
					,P3AverageCostRate			= ISNULL(RA.KimbleOne__P3AverageCostRate__c , 0 ) 
					,P3AverageRevenueRate		= ISNULL(RA.KimbleOne__P3AverageRevenueRate__c  , 0 ) 
					,P3Cost						= ISNULL(RA.KimbleOne__P3Cost__c , 0 ) 
					,P3ExpensesCost				= ISNULL(RA.KimbleOne__P3ExpensesCost__c  , 0 ) 
					,P3ExpensesRevenue			= ISNULL(RA.KimbleOne__P3ExpensesRevenue__c  , 0 ) 
					,P3Revenue					= ISNULL(RA.KimbleOne__P3Revenue__c  , 0 ) 
					,P3ServicesCost				= ISNULL(RA.KimbleOne__P3ServicesCost__c  , 0 ) 
					,P3ServicesRevenue			= ISNULL(RA.KimbleOne__P3ServicesRevenue__c  , 0 ) 

					,P1UsageOtherSales			= ISNULL(P1O.P1UsageOtherSales, 0 ) 
					,P1UsageOtherHoliday		= ISNULL(P1O.P1UsageOtherHoliday, 0 ) 
					,P1UsageOtherAbsence		= ISNULL(P1O.P1UsageOtherAbsence, 0 ) 
					,P1UsageOtherDMWApps		= ISNULL(P1O.P1UsageOtherDMWApps, 0 ) 
					,P1UsageOtherPeople			= ISNULL(P1O.P1UsageOtherPeople	, 0 ) 
					,P1UsageOtherTraining		= ISNULL(P1O.P1UsageOtherTraining, 0 ) 
					,P1UsageOtherStrategy		= ISNULL(P1O.P1UsageOtherStrategy, 0 ) 
					,P1UsageOtherSupport		= ISNULL(P1O.P1UsageOtherSupport, 0 ) 
					,P1UsageOtherTech			= ISNULL(P1O.P1UsageOtherTech, 0 ) 	
					,P1UsageOtherDelivery		= ISNULL(P1O.P1UsageOtherDelivery, 0 ) 
					,P1Other					= ISNULL(P1O.P1Other, 0 ) 

					,HolidayHours				= ISNULL(HL.HolidayHours, 0 ) 
					,HolidayDays				= ISNULL(HL.HolidayDays, 0 ) 

					,ActualUsage				= ISNULL(RSU.ActualUsage, 0 ) 
					,ForecastP1UtilisationIncludedUsage	= ISNULL(RSU.ForecastP1UtilisationIncludedUsage, 0 ) 
					,ForecastP1TrackedUsage		= ISNULL(RSU.ForecastP1TrackedUsage, 0 ) 
					,DeliveryUtilisationPctTgt	= ISNULL(RT.DeliveryUtilisationPctTgt, 0 ) 
					,RN = ROW_NUMBER()OVER	
							(
								PARTITION BY	RA.KimbleOne__Resource__c, TP.KimbleOne__StartDate__c--, EffectiveFromDate
								ORDER BY		RA.KimbleOne__Resource__c, TP.KimbleOne__StartDate__c, EffectiveFromDate DESC
							)
			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_ResourceAnalysis	RA	
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod		TP	ON	TP.id					= RA.KimbleOne__TimePeriod__c
															AND	TP._crda_isDeleted		= 0  
															AND	TP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType		PT	ON	PT.Id					= TP.KimbleOne__PeriodType__c
															AND PT._crda_isDeleted		= 0  
															AND	PT._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
															AND	PT.[Name]				= 'Month' 
			LEFT JOIN #P1OtherUsage						P1O	ON	P1O.PeriodStartDate = CAST(TP.KimbleOne__StartDate__c AS DATE)
															AND	P1O.PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE)
															AND	P1O.ResourceBk		= RA.KimbleOne__Resource__c 

			LEFT JOIN #Holidays							HL	ON	HL.PeriodStartDate	= CAST(TP.KimbleOne__StartDate__c AS DATE)
															AND	HL.PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE)
															AND	HL.ResourceBk		= RA.KimbleOne__Resource__c 

			LEFT JOIN #ResourceUsage					RSU	ON	RSU.PeriodStartDate	= CAST(TP.KimbleOne__StartDate__c AS DATE)
															AND	RSU.PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE)
															AND	RSU.ResourceBk		= RA.KimbleOne__Resource__c 

			LEFT JOIN #DelivUtilRsrcTgt					RT	ON	RT.PeriodStartDate	= CAST(TP.KimbleOne__StartDate__c AS DATE)
															AND	RT.PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE)
															AND	RT.ResourceBk		= RA.KimbleOne__Resource__c 

			LEFT JOIN #ResourcePracticeHistory			RPH	ON	RPH.ResourceBk		= RA.KimbleOne__Resource__c 
															AND	(RPH.EffectiveFromDate BETWEEN TP.KimbleOne__StartDate__c AND TP.KimbleOne__EndDate__c
																OR
																TP.KimbleOne__StartDate__c >= RPH.EffectiveFromDate AND	TP.KimbleOne__StartDate__c < RPH.EffectiveToDate) 

			WHERE	RA.KimbleOne__Resource__c IS NOT NULL 
			AND		RA._crda_ActiveFromDateTime >= @_Watermark 
			AND		RA ._crda_isDeleted = 0 
			AND		RA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			ORDER BY RA.KimbleOne__Resource__c, KimbleOne__StartDate__c ;



			INSERT INTO dbo.FactResourceAnalysis( 
					 ResourceSk
					,PeriodStartDate
					,PeriodEndDate
					,BusinessUnitSk
					,GradeSk 
					,ResourcePracticeSk 

					,CurrencySk 

					,FTE	
					,P1AvailableDays
					,P1DeliveryUtilisationDays
					,P1SalesUtilisationDays
					,P1OtherUtilisationDays
					,P1AverageCostRate
					,P1AverageRevenueRate
					,P1Cost
					,P1ExpensesCost
					,P1ExpensesRevenue
					,P1Revenue
					,P1ServicesCost
					,P1ServicesRevenue

					,P2AvailableDays
					,P2DeliveryUtilisationDays
					,P2SalesUtilisationDays
					,P2OtherUtilisationDays
					,P2AverageCostRate
					,P2AverageRevenueRate
					,P2Cost
					,P2ExpensesCost
					,P2ExpensesRevenue
					,P2Revenue
					,P2ServicesCost
					,P2ServicesRevenue

					,P3AvailableDays
					,P3DeliveryUtilisationDays
					,P3SalesUtilisationDays
					,P3OtherUtilisationDays
					,P3AverageCostRate
					,P3AverageRevenueRate
					,P3Cost
					,P3ExpensesCost
					,P3ExpensesRevenue
					,P3Revenue
					,P3ServicesCost
					,P3ServicesRevenue

					,P1UsageOtherSales
					,P1UsageOtherHoliday
					,P1UsageOtherAbsence
					,P1UsageOtherDMWApps
					,P1UsageOtherPeople
					,P1UsageOtherTraining
					,P1UsageOtherStrategy
					,P1UsageOtherSupport	
					,P1UsageOtherTech
					,P1UsageOtherDelivery
					,P1Other 

					,HolidayHours
					,HolidayDays	

					,TargetBusinessDays
					,TargetTrainingDays
					,TargetHolidaysDays
					,TargetOtherDays	

					,ActualUsage
					,ForecastP1UtilisationIncludedUsage
					,ForecastP1TrackedUsage
					,DeliveryUtilisationPctTgt

					,_crda_CreatedExecutionId
					,_crda_CreatedDateTime
				) 
				SELECT  
					 RO.ResourceSk 
					,SRC.PeriodStartDate
					,SRC.PeriodEndDate
					,BusinessUnitSk		= ISNULL(BU.BusinessUnitSk, -1)
					,GradeSk			= ISNULL(GR.GradeSk, -1)
					,ResourcePracticeSk	= ISNULL(PR.PracticeSk, -1)
					,CurrencySk			= ISNULL(DC.CurrencySk, -1)


					,SRC.FTE	
					,SRC.P1AvailableDays
					,SRC.P1DeliveryUtilisationDays
					,SRC.P1SalesUtilisationDays
					,SRC.P1OtherUtilisationDays
					,SRC.P1AverageCostRate
					,SRC.P1AverageRevenueRate
					,SRC.P1Cost
					,SRC.P1ExpensesCost
					,SRC.P1ExpensesRevenue
					,SRC.P1Revenue
					,SRC.P1ServicesCost
					,SRC.P1ServicesRevenue

					,SRC.P2AvailableDays
					,SRC.P2DeliveryUtilisationDays
					,SRC.P2SalesUtilisationDays
					,SRC.P2OtherUtilisationDays
					,SRC.P2AverageCostRate
					,SRC.P2AverageRevenueRate
					,SRC.P2Cost
					,SRC.P2ExpensesCost
					,SRC.P2ExpensesRevenue
					,SRC.P2Revenue
					,SRC.P2ServicesCost
					,SRC.P2ServicesRevenue

					,SRC.P3AvailableDays
					,SRC.P3DeliveryUtilisationDays
					,SRC.P3SalesUtilisationDays
					,SRC.P3OtherUtilisationDays
					,SRC.P3AverageCostRate
					,SRC.P3AverageRevenueRate
					,SRC.P3Cost
					,SRC.P3ExpensesCost
					,SRC.P3ExpensesRevenue
					,SRC.P3Revenue
					,SRC.P3ServicesCost
					,SRC.P3ServicesRevenue

					,SRC.P1UsageOtherSales
					,SRC.P1UsageOtherHoliday
					,SRC.P1UsageOtherAbsence
					,SRC.P1UsageOtherDMWApps
					,SRC.P1UsageOtherPeople
					,SRC.P1UsageOtherTraining
					,SRC.P1UsageOtherStrategy
					,SRC.P1UsageOtherSupport
					,SRC.P1UsageOtherTech
					,SRC.P1UsageOtherDelivery
					,SRC.P1Other 

					,SRC.HolidayHours
					,SRC.HolidayDays

					,ISNULL(MT.TargetBusinessDays, 0)
					,ISNULL(MT.TargetTrainingDays, 0)
					,ISNULL(MT.TargetHolidaysDays, 0)
					,ISNULL(MT.TargetOtherDays	, 0)

					,SRC.ActualUsage
					,SRC.ForecastP1UtilisationIncludedUsage
					,SRC.ForecastP1TrackedUsage	
					,SRC.DeliveryUtilisationPctTgt 	

					,@_ExecutionId 
					,GETUTCDATE() 
				FROM	#Source	SRC 
				INNER JOIN dbo.DimResource						RO	ON	RO.ResourceBk			= SRC.ResourceBk 
																	AND	RO._crda_ActiveToDate	= '9999-12-31 23:59:59'  

				INNER JOIN dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk		= SRC.ResourceBusinessUnitBk  
																	AND	BU._crda_ActiveToDate	= '9999-12-31 23:59:59'  

				LEFT JOIN dbo.DimCurrency						DC	ON	DC.CurrencyIsoCode		= SRC.CurrencyIsoCode  
																	AND	DC._crda_ActiveToDate	= '9999-12-31 23:59:59'   

				LEFT JOIN dbo.DimGrade							GR	ON	GR.GradeBk				= SRC.GradeBk  
																	AND	GR._crda_ActiveToDate	= '9999-12-31 23:59:59'  

				LEFT JOIN dbo.DimPractice						PR	ON	PR.PracticeBk			= SRC.ResourcePracticeBk  
																	AND	PR._crda_ActiveToDate	= '9999-12-31 23:59:59'  

				LEFT JOIN Internal.ResourceMonthlyTargetDays	MT	ON	MT.PeriodStartDate		= SRC.PeriodStartDate 
																	AND	MT.PeriodEndDate		= SRC.PeriodEndDate
																	AND	MT.BusinessUnitBk		= BU.BusinessUnitBk

				WHERE	SRC.RN = 1 
				ORDER BY ResourceSk, 
						 SRC.PeriodStartDate ; 



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