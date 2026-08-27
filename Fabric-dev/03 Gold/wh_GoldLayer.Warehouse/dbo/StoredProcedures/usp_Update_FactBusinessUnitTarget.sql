CREATE  
	PROCEDURE dbo.usp_Update_FactBusinessUnitTarget
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactBusinessUnitTarget]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactBusinessUnitTarget]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactBusinessUnitTarget]')
	EXEC dbo.usp_Update_FactBusinessUnitTarget @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactBusinessUnitTarget ;  
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35)= CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35)= CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
	DECLARE @WatermarkDate	DATE = @_Watermark ;
	DECLARE	@DateInTwoYears	DATE = DATEADD(MONTH, 25, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	BEGIN TRY

		BEGIN TRANSACTION 

			TRUNCATE TABLE dbo.FactBusinessUnitTarget ;

			DROP TABLE IF EXISTS #RevTargets ;
			DROP TABLE IF EXISTS #BuTargets ;
			DROP TABLE IF EXISTS #RevenueOmcTarget ;
			DROP TABLE IF EXISTS #PbtOmcTarget ;
			DROP TABLE IF EXISTS #RsrcDays ; 
			DROP TABLE IF EXISTS #RsrcDaysTgt ;
			DROP TABLE IF EXISTS #RevenueZeroPlusTwelve ;
			DROP TABLE IF EXISTS #AllDates ; 

			DECLARE @CrederaUKBu INT = (SELECT BusinessUnitSk FROM dbo.DimBusinessUnit WHERE BusinessUnitName = 'Credera UK' AND IsCurrent = 1);

			SELECT	 PeriodStartDate= CAST(TP.KimbleOne__StartDate__c AS DATE) 
					,PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE) 
					,RevenueTarget	= PA.KimbleOne__Target__c 
					,BusinessUnitSk	= COALESCE(BU.BusinessUnitSk, -1)
			INTO #RevTargets 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted			= 0 
																AND	PT.[Name]					= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																AND	BU.IsCurrent				= 1
 
			WHERE	PA._crda_isDeleted			= 0 
			AND		PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000ia99sMAA'	/*Business Unit*/ 
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0ED000000CxJIuMAN'	/*Revenue*/


			/*RevenueTarget (Employee)
			VIEW [Kimble].[vw_Revenue_EmpCompanyTarget]
			*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					BusinessUnitSk		= @CrederaUKBu ,
					EmpRevenueTarget	= PA.KimbleOne__CorporateCurrencyTarget__c ,
					RevenueStretchTarget= PA.KimbleOne__CorporateCurrencyStretchTarget__c 
			INTO #BuTargets 
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
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0E4K000000i5Q3UAI'	/*Revenue (Employee)*/
			AND		TP.KimbleOne__EndDate__c <= '20231231'	/*Prior to this date there was only one BU - Credera UK*/

			UNION ALL

			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					BusinessUnitSk		= COALESCE(BU.BusinessUnitSk, -1), 
					EmpRevenueTarget	= PA.KimbleOne__CorporateCurrencyTarget__c ,
					RevenueStretchTarget= PA.KimbleOne__CorporateCurrencyStretchTarget__c 

			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted			= 0 
																AND	PT.[Name]					= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																AND	BU.IsCurrent				= 1

			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000ia99sMAA'	/*Business Unit*/ 
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0E4K000000i5Q3UAI'	/*Revenue (Employee)*/ 
			AND		TP.KimbleOne__EndDate__c >= '20240131'	/*Multiple BU after this date*/


			/*#RevenueOmcTarget
			VIEW [Kimble].[vw_Revenue_OMC]*/
			SELECT	PeriodStartDate	 , 
					PeriodEndDate	, 
					BusinessUnitSk	= COALESCE(X.BusinessUnitSk, -1), 
					OmcTarget	, 
					OmcStretchTarget
			INTO #RevenueOmcTarget 
			FROM(
				SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						BusinessUnitSk		= @CrederaUKBu ,
						OmcTarget			= PA.KimbleOne__CorporateCurrencyTarget__c , 
						OmcStretchTarget	= PA.KimbleOne__CorporateCurrencyStretchTarget__c
				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																	AND	TP._crda_isDeleted			= 0  
																	AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																	AND PT._crda_isDeleted			= 0 
																	AND	PT.[Name]					= 'Month'
																	AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				WHERE	PA._crda_isDeleted				= 1 
				AND		PA._crda_ActiveToDateTime		= '9999-12-31 23:59:59'  
				AND		PA._crda_ActiveFromDateTime		>= @_Watermark 
				AND		PA.KimbleOne__AnalysisFact__c	= 'a0E4K000002dSONUA2'	/*Revenue (OMC)*/
				AND		TP.KimbleOne__EndDate__c		<= '20231231'	/*Prior to this date there was only one BU - Credera UK*/

				UNION ALL

				SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						BusinessUnitSk		= COALESCE(BU.BusinessUnitSk, -1), 
						OmcTarget			= PA.KimbleOne__CorporateCurrencyTarget__c , 
						OmcStretchTarget	= PA.KimbleOne__CorporateCurrencyStretchTarget__c
				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																	AND	TP._crda_isDeleted			= 0  
																	AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																	AND PT._crda_isDeleted			= 0 
																	AND	PT.[Name]					= 'Month'
																	AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																	AND	BU.IsCurrent				= 1
				WHERE	PA._crda_isDeleted					= 0  
				AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
				AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
				AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000ia99sMAA'	/*Business Unit*/
				AND		PA.KimbleOne__AnalysisFact__c		= 'a0E4K000002dSONUA2'	/*Revenue (OMC)*/
				AND		TP.KimbleOne__EndDate__c			> '20231231' /*Multiple BU after this date*/
			) X ; 

			/*#PbtOmcTarget
			VIEW [Kimble].[vw_EBIT_PBTTargets]*/
			SELECT	PeriodStartDate	 , 
					PeriodEndDate	, 
					BusinessUnitSk	= COALESCE(X.BusinessUnitSk, -1), 
					PbtOmcTarget
			INTO #PbtOmcTarget 
			FROM(
				SELECT	PeriodStartDate	= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						BusinessUnitSk	= @CrederaUKBu ,
						PbtOmcTarget	= PA.KimbleOne__CorporateCurrencyTarget__c 
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
				AND		PA.KimbleOne__AnalysisFact__c	= 'a0E4K000002dSOwUAM'	/*PBT (OMC)*/
				AND		TP.KimbleOne__EndDate__c		<= '20241231'	/*Prior to this date targets was at company level*/

				UNION ALL

				SELECT	PeriodStartDate	= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate	= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						BusinessUnitSk	= COALESCE(BU.BusinessUnitSk, -1), 
						PbtOmcTarget	= PA.KimbleOne__CorporateCurrencyTarget__c 
				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																	AND	TP._crda_isDeleted			= 0  
																	AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																	AND PT._crda_isDeleted			= 0 
																	AND	PT.[Name]					= 'Month'
																	AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
				LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																	AND	BU.IsCurrent				= 1
				WHERE	PA._crda_isDeleted					= 0  
				AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
				AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
				AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000ia99sMAA'	/*Business Unit*/ 
				AND		PA.KimbleOne__AnalysisFact__c		= 'a0E4K000002dSOwUAM'	/*PBT (OMC)*/
				AND		TP.KimbleOne__EndDate__c			> '20241231'	/*After this date targets at BU level*/
			) X ; 


			/*Resource3Target 
			VIEW [Kimble].[vw_Resource3_DaysSummary] - Target_AllDays*/
			SELECT		 PeriodStartDate	= TP.KimbleOne__StartDate__c
						,PeriodEndDate		= TP.KimbleOne__EndDate__c
						,BusinessUnitSk		= COALESCE(BU.BusinessUnitSk , @CrederaUKBu)

						,AnalysisDimension	= AD.[Name] 
						,AnalysisFact		=	CASE 
																/* NumberOfBusinessDays				Company*/ 
													WHEN AF.Id = 'a0ED000000tiX3pMAE' AND AD.Id IN ('a0DD000000B4H56MAF') 
														THEN	'ResourceBusinessDays'

																/* NumberOfOtherDays				Company*/ 
													WHEN AF.Id = 'a0E3z00000tbtJAEAY' AND AD.Id IN ('a0DD000000B4H56MAF') 
														THEN	'ResourceOtherDays'

																/* NumberOfHolidayDays				Business Unit*/ 
													WHEN AF.Id = 'a0E3z00000ve7fXEAQ' AND AD.Id IN ('a0DD000000ia99sMAA') 
														THEN	'ResourceHolidayDays'

																/* NumberOfTrainingDays				Company*/ 
													WHEN AF.Id = 'a0E3z00000ve7fSEAQ' AND AD.Id IN ('a0DD000000B4H56MAF') 
														THEN	'ResourceTrainingDays'
													ELSE 
														NULL 
												END 
						,TargetAmount		= PA.KimbleOne__TargetAmount__c
			INTO #RsrcDays 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisDimension	AD 	ON  AD.Id	= PA.KimbleOne__AnalysisDimension__c
																AND AD._crda_isDeleted			= 0 
																AND	AD._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisFact			AF  ON	AF.Id	= PA.KimbleOne__AnalysisFact__c
																AND AF._crda_isDeleted			= 0 
																AND	AF._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id	= PA.KimbleOne__TimePeriod__c
																AND TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																AND	BU.IsCurrent				= 1

			WHERE		(
							(
								AF.Id IN (	'a0E3z00000tbtJAEAY' /*'NumberOfOtherDays'*/ ,
											'a0E3z00000ve7fSEAQ' /*'NumberOfTrainingDays'*/ ,
											'a0E3z00000ve7fXEAQ' /*'NumberOfHolidayDays'*/ ,
											'a0ED000000tiX3pMAE' /*'NumberOfBusinessDays'*/ )
							
								AND AD.Id IN(
												'a0DD000000B4H56MAF', /*Company*/
												'a0DD000000ia99sMAA'  /*Business Unit*/
											)
							)
						) 

			AND			PA._crda_isDeleted = 0 
			AND			PA._crda_ActiveToDateTime	= '99991231'; 


			/*Revenue (0+12) */
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					BusinessUnitSk		= COALESCE(BU.BusinessUnitSk, -1), 
					RevenueZeroPlusTwelveTarget			= PA.KimbleOne__CorporateCurrencyTarget__c ,
					RevenueZeroPlusTwelveStretchTarget	= PA.KimbleOne__CorporateCurrencyStretchTarget__c 
			INTO #RevenueZeroPlusTwelve 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis PA
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																AND	TP._crda_isDeleted			= 0  
																AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																AND PT._crda_isDeleted			= 0 
																AND	PT.[Name]					= 'Month'
																AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																AND	BU.IsCurrent				= 1

			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000ia99sMAA'	/*Business Unit*/ 
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0EPx00000Ec8apMAB'	/*Revenue (0+12)*/ 
			AND		TP.KimbleOne__EndDate__c >= '20240131'	/*Multiple BU after this date*/




			SELECT	 PVT.PeriodStartDate 
					,PVT.PeriodEndDate 
					,PVT.BusinessUnitSk
					,ResourceBusinessDays	= SUM(COALESCE(PVT.ResourceBusinessDays , 0 ))
					,ResourceTrainingDays	= SUM(COALESCE(PVT.ResourceTrainingDays , 0 ))
					,ResourceHolidayDays	= SUM(COALESCE(PVT.ResourceHolidayDays , 0 ))
					,ResourceOtherDays		= SUM(COALESCE(PVT.ResourceOtherDays , 0 ))
			INTO #RsrcDaysTgt
			FROM	#RsrcDays Src
			PIVOT (
				MAX(TargetAmount)  
				FOR AnalysisFact IN ([ResourceBusinessDays], [ResourceTrainingDays], [ResourceHolidayDays], [ResourceOtherDays])  
			) PVT
			GROUP BY
					 PVT.PeriodStartDate 
					,PVT.PeriodEndDate 
					,PVT.BusinessUnitSk
			ORDER BY 
					 PVT.PeriodStartDate 
					,PVT.PeriodEndDate ;


			

			SELECT	PeriodStart		= [Date] , 
					PeriodStartSk	= DateSk , 
					PeriodEnd		= EOMONTH([Date]) , 
					PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT) , 
					BU.BusinessUnitSk 
			INTO #AllDates 

			FROM	dbo.DimDate 
			CROSS APPLY ( 
				SELECT	B.BusinessUnitBk, BusinessUnitSk = B2.BusinessUnitSk , 
						ActiveFrom	= MIN(DATEFROMPARTS(YEAR(B._crda_ActiveFromDate), MONTH(B._crda_ActiveFromDate), 1)) ,
						ActiveTo	= MAX(CAST(B._crda_ActiveToDate AS DATE)) 
				FROM	dbo.DimBusinessUnit B 

				LEFT JOIN (
					SELECT	B1.BusinessUnitBk, B1.BusinessUnitSk
					FROM	dbo.DimBusinessUnit B1 
					WHERE	B1.IsCurrent = 1 
				)	B2	ON	B2.BusinessUnitBk = B.BusinessUnitBk 

				WHERE B.BusinessUnitSk > 1
				GROUP BY 
					B.BusinessUnitBk, B2.BusinessUnitSk 
			)	BU 

			WHERE	DayNumberInMonth = 1 
			AND		[Date] >= BU.ActiveFrom AND [Date] <= BU.ActiveTo
			AND		[Date] <= @DateInTwoYears 
			

			INSERT INTO dbo.FactBusinessUnitTarget
			(
				 PeriodStart
				,PeriodEnd
				,PeriodStartSk 
				,PeriodEndSk 
				,BusinessUnitSk

				,RevenueTarget
					
				,EmpRevenueTarget
				,RevenueStretchTarget

				,OmcTarget
				,OmcStretchTarget

				,PbtOmcTarget 

				,RevenueZeroPlusTwelveTarget
				,RevenueZeroPlusTwelveStretchTarget

				,ResourceBusinessDays
				,ResourceTrainingDays
				,ResourceHolidayDays
				,ResourceOtherDays	

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
				,_crda_PK_JoinHash 
			) 
			SELECT	
				 A.PeriodStart 
				,A.PeriodEnd 
				,(CONVERT([int],CONVERT([varchar](8),A.PeriodStart,(112)))) 
				,(CONVERT([int],CONVERT([varchar](8),A.PeriodEnd,(112)))) 
				,A.BusinessUnitSk 

				,RevenueTarget		= COALESCE(ReT.RevenueTarget , 0) ,

				EmpRevenueTarget	= COALESCE(AV.EmpRevenueTarget , 0) ,
				RevenueStretchTarget= COALESCE(AV.RevenueStretchTarget , 0) , 

				OmcTarget			= COALESCE(OT.OmcTarget ,0) ,
				OmcStretchTarget	= COALESCE(OT.OmcStretchTarget ,0) ,

				PbtOmcTarget		= COALESCE(PT.PbtOmcTarget, 0) ,

				RevenueZeroPlusTwelveTarget			= COALESCE(ZP.RevenueZeroPlusTwelveTarget ,0) ,
				RevenueZeroPlusTwelveStretchTarget	= COALESCE(ZP.RevenueZeroPlusTwelveStretchTarget ,0) ,

				ResourceBusinessDays= COALESCE(RT.ResourceBusinessDays, 0) ,
				ResourceTrainingDays= COALESCE(RT.ResourceTrainingDays, 0) ,
				ResourceHolidayDays = COALESCE(RT.ResourceHolidayDays, 0) ,
				ResourceOtherDays	= COALESCE(RT.ResourceOtherDays, 0) 

				,@_ExecutionId 
				,GETUTCDATE() 
				,CAST (HASHBYTES('MD5', CONCAT_WS('||', A.PeriodStart, A.PeriodEnd, A.BusinessUnitSk)) AS VARBINARY (16))

			FROM	#AllDates				A 

			LEFT JOIN	#RevTargets			ReT	ON	ReT.PeriodStartDate	= A.PeriodStart 
												AND	ReT.PeriodEndDate	= A.PeriodEnd 
												AND	ReT.BusinessUnitSk	= A.BusinessUnitSk

			LEFT JOIN	#BuTargets			AV	ON	AV.PeriodStartDate	= A.PeriodStart 
												AND	AV.PeriodEndDate	= A.PeriodEnd 
												AND	AV.BusinessUnitSk	= A.BusinessUnitSk

			LEFT JOIN	#RevenueOmcTarget	OT	ON	OT.PeriodStartDate	= A.PeriodStart 
												AND	OT.PeriodEndDate	= A.PeriodEnd 
												AND	OT.BusinessUnitSk	= A.BusinessUnitSk 

			LEFT JOIN	#PbtOmcTarget		PT	ON	PT.PeriodStartDate	= A.PeriodStart 
												AND	PT.PeriodEndDate	= A.PeriodEnd 
												AND	PT.BusinessUnitSk	= A.BusinessUnitSk 

			LEFT JOIN	#RsrcDaysTgt		RT	ON	RT.PeriodStartDate	= A.PeriodStart 
												AND	RT.PeriodEndDate	= A.PeriodEnd 
												AND	RT.BusinessUnitSk	= A.BusinessUnitSk 

			LEFT JOIN	#RevenueZeroPlusTwelve	ZP	ON	ZP.PeriodStartDate	= A.PeriodStart 
													AND	ZP.PeriodEndDate	= A.PeriodEnd 
													AND	ZP.BusinessUnitSk	= A.BusinessUnitSk 

			ORDER BY	A.PeriodStart, 
						A.PeriodEnd ,
						A.BusinessUnitSk ;

			;WITH cteDuplicates
			AS(	/*PK/Unique constraints are not enforced so...*/ 
				SELECT	PeriodStart, PeriodEnd, BusinessUnitSk, 
						RN = ROW_NUMBER()
								OVER(
									PARTITION BY PeriodStart, PeriodEnd, BusinessUnitSk 
									ORDER BY	PeriodStart, PeriodEnd
								)
				FROM	dbo.FactBusinessUnitTarget T
			)
			DELETE	FROM cteDuplicates	
			WHERE	RN > 1 ; 


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