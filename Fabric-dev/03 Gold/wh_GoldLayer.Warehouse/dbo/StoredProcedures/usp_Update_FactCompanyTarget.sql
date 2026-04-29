CREATE   
	PROCEDURE dbo.usp_Update_FactCompanyTarget
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactCompanyTarget]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactCompanyTarget]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactCompanyTarget]')
	EXEC dbo.usp_Update_FactCompanyTarget @ExecutionId = @ExecutionId, @Watermark ='20180101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactCompanyTarget ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35)= CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35)= CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow			DATETIME2= GETUTCDATE() ;
	DECLARE @WatermarkDate		DATE = @_Watermark ;
	DECLARE	@DateInTwoYears	DATE = DATEADD(MONTH, 25, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	BEGIN TRY

		BEGIN TRANSACTION 

			TRUNCATE TABLE dbo.FactCompanyTarget ; 

			DROP TABLE IF EXISTS #RevenueCompanyTarget ;
			DROP TABLE IF EXISTS #SalesTypeTarget ;
			DROP TABLE IF EXISTS #RevenueDays ;
			DROP TABLE IF EXISTS #MarginTargets ;

			/*#RevenueCompanyTarget
			VIEW [Kimble].[vw_Revenue_CompanyTarget]*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					CompanyTargetAmount			= PA.KimbleOne__CorporateCurrencyTarget__c , 
					CompanyStretchTargetAmount	= PA.KimbleOne__CorporateCurrencyStretchTarget__c
			INTO #RevenueCompanyTarget 	
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted			= 0 
																AND	PT.[Name]					= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000B4H56MAF'	/*Company*/
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0ED000000CxJIuMAN';	/*Revenue*/


			/*#SalesTypeTarget
			VIEW [Kimble].[vw_Revenue_Targets_SalesType]*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					NewBusinessTargetAmount	= MAX(IIF( KC_NewBusiness__c = 1 , PA.KimbleOne__CorporateCurrencyTarget__c, NULL)) , 
					AccountMgmtTargetAmount	= MAX(IIF( KC_NewBusiness__c = 0 , PA.KimbleOne__CorporateCurrencyTarget__c, NULL))
			INTO #SalesTypeTarget 	
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted			= 0 
																AND	PT.[Name]					= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0D3z00000jcxRlEAI'	/*Sector by BD/AM*/
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0ED000000CxJIuMAN'	/*Revenue*/
			GROUP BY 
					CAST(TP.KimbleOne__StartDate__c AS DATE) ,
					CAST(TP.KimbleOne__EndDate__c AS DATE) ;


			/*#RevenueDays
			VIEW [Kimble].[vw_Revenue_ForecastGradeRev_Days]
			VIEW [Kimble].[vw_Revenue_ForecastGradeRev_OthDays]
			*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					NumberOfBusinessDays	= SUM(
													IIF(PA.KimbleOne__AnalysisFact__c = 'a0ED000000tiX3pMAE',	/*NumberOfBusinessDays*/
														KimbleOne__TargetAmount__c, NULL )
												) ,
					NumberOfOtherDays		= SUM(
													IIF(PA.KimbleOne__AnalysisFact__c = 'a0E3z00000tbtJAEAY',	/*NumberOfOtherDays*/
														KimbleOne__TargetAmount__c, NULL )
												) 

			INTO #RevenueDays 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted			= 0 
																AND	PT.[Name]					= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000B4H56MAF'			--Company
			AND		PA.KimbleOne__AnalysisFact__c		IN (
																'a0ED000000tiX3pMAE',	--NumberOfBusinessDays
																'a0E3z00000tbtJAEAY'	--NumberOfOtherDays
															)
			GROUP BY	CAST(TP.KimbleOne__StartDate__c AS DATE) ,  
						CAST(TP.KimbleOne__EndDate__c AS DATE) ;



			
			/*VIEW [Kimble].[vw_TargetMargin]*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					CompanyTargetMargin	= SUM(
											IIF
												(AF.Id = 'a0ED000000CxJIwMAN' /*Margin (Std %)'*/, 
													(PA.KimbleOne__TargetAmount__c) , 
													0
												) ) , 
					CompanyTargetPercent= SUM(
											IIF
												(AF.Id = 'a0ED000000CxJIwMAN' /*Margin (Std %)'*/, 
													100 * (PA.KimbleOne__TargetAmount__c) , 
													0
												) ) , 
					CompanyTargetAssociateMargin
										= SUM(
												IIF
												(AF.Id = 'a0E4K000001MxP0UAK' /*'Margin (Assoc %)'*/, 
													(PA.KimbleOne__TargetAmount__c) , 
													0
												) ) , 
					CompanyTargetAssociatePercent
										= SUM(
												IIF
												(AF.Id = 'a0E4K000001MxP0UAK' /*'Margin (Assoc %)'*/, 
													100 * (PA.KimbleOne__TargetAmount__c) , 
													0
												) ) 
			INTO #MarginTargets 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA	

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	TP	ON  PA.KimbleOne__TimePeriod__c = TP.Id
																		AND TP._crda_isDeleted			= 0 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																		AND PT._crda_isDeleted			= 0 
																		AND	PT.[Name]					= 'Month'
																		AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisFact	AF	ON	AF.Id	= PA.KimbleOne__AnalysisFact__c
																		AND AF._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																		AND	AF._crda_isDeleted			= 0  
																		AND	AF.Id IN (	'a0E4K000001MxP0UAK',	/*'Margin (Assoc %)'*/
																						'a0ED000000CxJIwMAN'	/*'Margin (Std %)'*/)

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisDimension	AD	ON	AD.Id	= PA.KimbleOne__AnalysisDimension__c
																				AND AD._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																				AND	AD._crda_isDeleted = 0 
																				AND AD.Id IN ('a0DD000000B4H56MAF' /*'Company'*/) 

			WHERE	PA._crda_isDeleted			= 0
			AND		PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'   
			AND		PA._crda_ActiveFromDateTime	>= @_Watermark 

			GROUP BY	CAST(TP.KimbleOne__StartDate__c AS DATE),
						CAST(TP.KimbleOne__EndDate__c AS DATE) ;


			DROP TABLE IF EXISTS #Source ;

			WITH cteAllDates
			AS(
				SELECT	PeriodStart		= [Date] , 
						PeriodStartSk	= DateSk , 
						PeriodEnd		= EOMONTH([Date]) ,
						PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT)
				FROM	dbo.DimDate
				WHERE	DayNumberInMonth = 1 
				AND		[Date] >= @WatermarkDate
				AND		[Date] <= @DateInTwoYears 
			)
			SELECT	A.PeriodStart ,
					A.PeriodEnd , 
					ST.NewBusinessTargetAmount , 
					ST.AccountMgmtTargetAmount ,
					CT.CompanyTargetAmount ,
					CT.CompanyStretchTargetAmount ,

					GR.NumberOfBusinessDays ,
					GR.NumberOfOtherDays ,

					MT.CompanyTargetMargin , 
					MT.CompanyTargetPercent ,
					MT.CompanyTargetAssociateMargin ,
					MT.CompanyTargetAssociatePercent ,
					RN = ROW_NUMBER()
							OVER(	/*PK/Unique constraints are not enforced so...*/ 
								PARTITION BY A.PeriodStart, A.PeriodEnd   
								ORDER BY	A.PeriodStart, A.PeriodEnd
							)

			INTO #Source 
			FROM	cteAllDates		A 
			LEFT JOIN	#SalesTypeTarget		ST	ON	ST.PeriodStartDate	= A.PeriodStart 
													AND	ST.PeriodEndDate	= A.PeriodEnd 

			LEFT JOIN	#RevenueCompanyTarget	CT	ON	CT.PeriodStartDate	= A.PeriodStart 
													AND	CT.PeriodEndDate	= A.PeriodEnd 

			LEFT JOIN	#RevenueDays			GR	ON	GR.PeriodStartDate	= A.PeriodStart 
													AND	GR.PeriodEndDate	= A.PeriodEnd 

			LEFT JOIN	#MarginTargets			MT	ON	MT.PeriodStartDate	= A.PeriodStart 
													AND	MT.PeriodEndDate	= A.PeriodEnd 

			ORDER BY	A.PeriodStart, 
						A.PeriodEnd ; 


			INSERT INTO	dbo.FactCompanyTarget  
			(
				 PeriodStart
				,PeriodEnd
				,PeriodStartSk 
				,PeriodEndSk 

				,NewBusinessTargetAmount
				,AccountMgmtTargetAmount
				,CompanyTargetAmount
				,CompanyStretchTargetAmount

				,NumberOfBusinessDays
				,NumberOfOtherDays

				,CompanyTargetMargin
				,CompanyTargetPercent
				,CompanyTargetAssociateMargin
				,CompanyTargetAssociatePercent

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
				,_crda_PK_JoinHash 
			)
			SELECT
				 SRC.PeriodStart
				,SRC.PeriodEnd
				,(CONVERT([int],CONVERT([varchar](8),PeriodStart,(112)))) 
				,(CONVERT([int],CONVERT([varchar](8),PeriodEnd,(112)))) 

				,SRC.NewBusinessTargetAmount
				,SRC.AccountMgmtTargetAmount
				,SRC.CompanyTargetAmount
				,SRC.CompanyStretchTargetAmount

				,SRC.NumberOfBusinessDays
				,SRC.NumberOfOtherDays

				,SRC.CompanyTargetMargin
				,SRC.CompanyTargetPercent
				,SRC.CompanyTargetAssociateMargin
				,SRC.CompanyTargetAssociatePercent

				,@_ExecutionId 
				,GETUTCDATE() 
				,CAST (HASHBYTES('MD5', CONCAT_WS('||', PeriodStart, PeriodEnd)) AS VARBINARY (16))
			FROM	#Source SRC 
			WHERE	RN = 1 
			ORDER BY PeriodStart, PeriodEnd ;

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),@_Watermark,121);
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