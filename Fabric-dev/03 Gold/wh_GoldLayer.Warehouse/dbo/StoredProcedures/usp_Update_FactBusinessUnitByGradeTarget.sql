CREATE  
	PROCEDURE dbo.usp_Update_FactBusinessUnitByGradeTarget
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	USAGE 

	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactBusinessUnitByGradeTarget]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactBusinessUnitByGradeTarget]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactBusinessUnitByGradeTarget]')
	EXEC dbo.usp_Update_FactBusinessUnitByGradeTarget @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM dbo.FactBusinessUnitByGradeTarget WHERE RevenueTarget >0; 
	SELECT * FROM dbo.FactBusinessUnitByGradeTarget 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME = '20000101',	/*Groundhog Day*/
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow			DATETIME2= GETUTCDATE() ;
	DECLARE @WatermarkDate		DATE = @_Watermark ;
	DECLARE	@DateIn18Months		DATE = DATEADD(MONTH, 19, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	BEGIN TRY

		BEGIN TRANSACTION 


			TRUNCATE TABLE dbo.FactBusinessUnitByGradeTarget ; 

			DROP TABLE IF EXISTS #Source ;
			DROP TABLE IF EXISTS #BuGradeTargets ;

			/*AverageRevenueRate
			VIEW [Kimble].[vw_Revenue_ForecastGradeRev_Rate]
			VIEW [Kimble].[vw_Revenue_ForecastGradeRev_Util]
			VIEW [Kimble].[vw_Revenue_Targets_BUGrade]
			*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					BusinessUnitSk		= COALESCE(BU.BusinessUnitSk, -1), 
					GradeSk				= COALESCE(DG.GradeSk, -1), 
					AverageRevenueRate	= MAX(
												IIF(PA.KimbleOne__AnalysisFact__c = 'a0ED000000tiX3tMAE'	/*AverageRevenueRate*/ ,
													PA.KimbleOne__CorporateCurrencyTarget__c ,
													0)),
					DeliveryUtilisationPct= MAX(
												IIF(PA.KimbleOne__AnalysisFact__c = 'a0ED000000tiX3qMAE'	/*DeliveryUtilisationPct*/ ,
													PA.KimbleOne__TargetAmount__c ,
													0)),
					RevenueTarget			= MAX(
												IIF(PA.KimbleOne__AnalysisFact__c = 'a0ED000000CxJIuMAN'	/*Revenue*/ ,
													PA.KimbleOne__CorporateCurrencyTarget__c ,
													0)),
					DeliveryResourceCount	= MAX(
												IIF(PA.KimbleOne__AnalysisFact__c = 'a0ED000000tiX3vMAE'	/*DeliveryResourceCount*/ ,
													PA.KimbleOne__TargetAmount__c ,
													0)) ,
					_crda_ActiveFromDateTime = MAX(PA._crda_ActiveFromDateTime)
			INTO #BuGradeTargets 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																				AND	TP._crda_isDeleted			= 0  
																				AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																		AND PT._crda_isDeleted			= 0 
																		AND	PT.[Name]					= 'Month'
																		AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			LEFT JOIN	dbo.DimGrade						DG	ON	DG.GradeBk					= PA.KimbleOne__Grade__c 
																AND	DG.IsCurrent				= 1

			LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																AND	BU.IsCurrent				= 1


			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000ia99tMAA'	/*Business Unit by Grade*/
			AND		PA.KimbleOne__AnalysisFact__c		IN	(
																'a0ED000000tiX3tMAE',	/*AverageRevenueRate*/ 
																'a0ED000000tiX3qMAE',	/*DeliveryUtilisationPct*/
																'a0ED000000CxJIuMAN',	/*Revenue*/
																'a0ED000000tiX3vMAE'	/*DeliveryResourceCount*/
															) 
														
			GROUP BY	CAST(TP.KimbleOne__StartDate__c AS DATE) ,
						CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						COALESCE(BU.BusinessUnitSk, -1), 
						COALESCE(DG.GradeSk, -1);



			WITH cteAllDates
			AS(
				SELECT	PeriodStart		= [Date] , 
						PeriodStartSk	= DateSk , 
						PeriodEnd		= EOMONTH([Date]) ,
						PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT) , 
						BU.BusinessUnitSk 
				FROM	dbo.DimDate 
				CROSS APPLY (
					SELECT	B.BusinessUnitSk 
					FROM	dbo.DimBusinessUnit B 
					WHERE	B.IsCurrent = 1 
				)	BU 
				WHERE	DayNumberInMonth = 1 
				AND		[Date] >= @WatermarkDate
				AND		[Date] <= @DateIn18Months 
			)
			SELECT	A.PeriodStart ,
					A.PeriodEnd , 
					A.BusinessUnitSk ,
					GradeSk					= COALESCE(AV.GradeSk ,-1) ,

					AverageRevenueRate		= COALESCE(AV.AverageRevenueRate , 0) ,
					DeliveryUtilisationPct	= COALESCE(AV.DeliveryUtilisationPct , 0) ,
					RevenueTarget			= COALESCE(AV.RevenueTarget, 0),
					DeliveryResourceCount	= COALESCE(AV.DeliveryResourceCount, 0) , 
					RN = ROW_NUMBER()
							OVER(	/*PK/Unique constraints are not enforced so...*/ 
								PARTITION BY A.PeriodStart, A.PeriodEnd, A.BusinessUnitSk, COALESCE(AV.GradeSk ,-1)   
								ORDER BY	A.PeriodStart, A.PeriodEnd
							)

			INTO #Source 
			FROM	cteAllDates				A 
			LEFT JOIN	#BuGradeTargets		AV	ON	AV.PeriodStartDate	= A.PeriodStart 
												AND	AV.PeriodEndDate	= A.PeriodEnd 
												AND	AV.BusinessUnitSk	= A.BusinessUnitSk ; 



			

			INSERT INTO dbo.FactBusinessUnitByGradeTarget
			( 
				 PeriodStart 
				,PeriodEnd 
				,PeriodStartSk 
				,PeriodEndSk 
				,BusinessUnitSk
				,GradeSk

				,AverageRevenueRate
				,DeliveryUtilisationPct
				,RevenueTarget
				,DeliveryResourceCount

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
				,_crda_PK_JoinHash
			)
			SELECT
				 SRC.PeriodStart
				,SRC.PeriodEnd
				,(CONVERT([int],CONVERT([varchar](8),PeriodStart,(112)))) 
				,(CONVERT([int],CONVERT([varchar](8),PeriodEnd,(112)))) 
				,SRC.BusinessUnitSk
				,SRC.GradeSk

				,SRC.AverageRevenueRate
				,SRC.DeliveryUtilisationPct 
				,SRC.RevenueTarget
				,SRC.DeliveryResourceCount

				,@_ExecutionId 
				,GETUTCDATE() 
				,CAST (HASHBYTES('MD5', CONCAT_WS('||', PeriodStart, PeriodEnd, BusinessUnitSk, GradeSk)) AS VARBINARY (16))
			FROM #Source SRC 
			WHERE	SRC.RN = 1 
			ORDER BY	PeriodStart, 
						PeriodEnd ,
						BusinessUnitSk ,
						GradeSk ; 


			SELECT @strOldWatermark	= CONVERT(VARCHAR(35),@_Watermark,121);
			SELECT @strNewWatermark = CONVERT(VARCHAR(35),COALESCE(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #BuGradeTargets S ;


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