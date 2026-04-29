CREATE   
	PROCEDURE dbo.usp_Update_FactAccountBusinessUnitTarget
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactAccountBusinessUnitTarget]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactAccountBusinessUnitTarget]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactAccountBusinessUnitTarget]')
	EXEC dbo.usp_Update_FactAccountBusinessUnitTarget @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM [dbo].[FactAccountBusinessUnitTarget] -- WHERE RevenueTargetAmount > 0 ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE	@PeriodStart	DATE		= '20150101'; 
	SET		@_Watermark		= IIF(	CAST(@Watermark AS DATETIME2) = '20000101', 
										@PeriodStart, 
										@Watermark
								  ) ;
	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);


	DECLARE @CrederaUKBu	INT = (	SELECT	BusinessUnitSk 
									FROM	dbo.DimBusinessUnit 
									WHERE	BusinessUnitName = 'Credera UK' AND IsCurrent = 1); 
	DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
	DECLARE	@DateIn12Months	DATE = DATEADD(MONTH, 12, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #FactAccBUTarget ;
			DROP TABLE IF EXISTS #ExplodeAccountDates ;
			TRUNCATE TABLE dbo.FactAccountBusinessUnitTarget ;

			/*#RevenueTarget
			VIEW [Kimble].[vw_AccMgmt_TargetRev_Account]*/
			SELECT	PeriodStartDate	 , 
					PeriodEndDate	, 
					AccountSk		= X.AccountSk , 
					BusinessUnitSk	= COALESCE(X.BusinessUnitSk, -1), 
					CAST(RevenueTargetAmount AS DECIMAL(18,2))	AS RevenueTargetAmount
			INTO #FactAccBUTarget  
			FROM(
				SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) , 
						AccountSk			= AC.AccountSk, 
						BusinessUnitSk		= @CrederaUKBu ,
						RevenueTargetAmount	= SUM(PA.KimbleOne__CorporateCurrencyTarget__c )
				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis  PA

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																					AND	TP._crda_isDeleted			= 0  
																					AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																			AND PT._crda_isDeleted			= 0 
																			AND	PT.[Name]					= 'Month'
																			AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

				INNER JOIN	dbo.DimAccount						AC	ON	AC.AccountBk				= PA.KimbleOne__Account__c 
																	AND	AC.IsCurrent				= 1
				WHERE	PA._crda_isDeleted					= 0 
				AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
				AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
				AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000B4H55MAF'	/*Account*/
				AND		PA.KimbleOne__AnalysisFact__c		= 'a0ED000000CxJIuMAN'	/*Revenue*/
				AND		TP.KimbleOne__EndDate__c			< '20250101'			/*Prior to this date there was only one BU - Credera UK*/
				GROUP BY 
					CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					AC.AccountSk 

				UNION ALL

				SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
						PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
						AccountSk			= AC.AccountSk , 
						BusinessUnitSk		= COALESCE(BU.BusinessUnitSk, -1), 
						RevenueTargetAmount	= SUM(PA.KimbleOne__CorporateCurrencyTarget__c )
				FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																					AND	TP._crda_isDeleted			= 0  
																					AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																			AND PT._crda_isDeleted			= 0 
																			AND	PT.[Name]					= 'Month'
																			AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

				INNER JOIN	dbo.DimAccount						AC	ON	AC.AccountBk				= PA.KimbleOne__Account__c 
																	AND	AC.IsCurrent				= 1

				LEFT JOIN	dbo.DimBusinessUnit					BU	ON	BU.BusinessUnitBk			= PA.KimbleOne__BusinessUnit__c 
																	AND	BU.IsCurrent				= 1

				WHERE	PA._crda_isDeleted					= 0  
				AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
				AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
				AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DPx000008VFPZMA4'	/*Business Unit By Account*/
				AND		PA.KimbleOne__AnalysisFact__c		= 'a0ED000000CxJIuMAN'	/*Revenue*/
				AND		TP.KimbleOne__EndDate__c			>= '20250101'			/*Multiple BU after this date*/ 
				GROUP BY 
					CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					AC.AccountSk ,
					COALESCE(BU.BusinessUnitSk, -1) 

			) X ; 

			SELECT	PeriodStart		= D.[Date] , 
					PeriodStartSk	= D.DateSk , 
					PeriodEnd		= EOMONTH(D.[Date]) , 
					PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH(D.[Date]), 112) AS INT) , 
					BU.AccountSk 
			INTO #ExplodeAccountDates 
			FROM	dbo.DimDate D 
			CROSS APPLY ( 
				SELECT	B.AccountBk, 
						B2.AccountSk AS AccountSk , 
						ActiveFrom	= MIN(DATEFROMPARTS(YEAR(B._crda_ActiveFromDate), MONTH(B._crda_ActiveFromDate), 1)) ,
						ActiveTo	= MAX(CAST(B._crda_ActiveToDate AS DATE)) 
				FROM	dbo.DimAccount B 
				LEFT JOIN (
							SELECT	B1.AccountBk, B1.AccountSk
							FROM	dbo.DimAccount B1 
							GROUP BY B1.AccountBk, B1.AccountSk

				)	B2	ON	B2.AccountBk = B.AccountBk 
				WHERE	B.AccountSk > 1
				AND		B._crda_isDeleted = 0
				GROUP BY 
					B.AccountBk, B2.AccountSk 
			)	BU 
			WHERE	D.DayNumberInMonth = 1 
			AND		D.[Date] >= IIF(BU.ActiveFrom < @PeriodStart, @PeriodStart, BU.ActiveFrom)
			AND		D.[Date] <= BU.ActiveTo
			AND		D.[Date] <= @DateIn12Months ; 

			INSERT INTO dbo.FactAccountBusinessUnitTarget
			(	
			   PeriodStart 
			  ,PeriodEnd 
			  ,PeriodStartSk 
			  ,PeriodEndSk 
			  ,AccountSk 
			  ,BusinessUnitSk 
			  ,RevenueTargetAmount 
			  ,_crda_CreatedExecutionId 
			  ,_crda_CreatedDateTime 
			  ,_crda_PK_JoinHash
			)
			SELECT	A.PeriodStart ,
					A.PeriodEnd , 
					(CONVERT([int],CONVERT([varchar](8),PeriodStart,(112)))) , 
					(CONVERT([int],CONVERT([varchar](8),PeriodEnd,(112)))) , 
					A.AccountSk  ,
					BusinessUnitSk		= COALESCE(FS.BusinessUnitSk , @CrederaUKBu,  -1) ,
					RevenueTargetAmount	= COALESCE(FS.RevenueTargetAmount ,0) , 
					@_ExecutionId ,
					GETUTCDATE() ,
					CAST (HASHBYTES('MD5', 
							CONCAT_WS('||', 
									A.PeriodStart, 
									A.PeriodEnd, 
									A.AccountSk, 
									COALESCE(FS.BusinessUnitSk , @CrederaUKBu,-1))
					) AS BINARY (16)) 

			FROM	#ExplodeAccountDates	A 
			LEFT JOIN	#FactAccBUTarget	FS	ON	FS.PeriodStartDate	= A.PeriodStart 
												AND	FS.PeriodEndDate	= A.PeriodEnd 
												AND	FS.AccountSk		= A.AccountSk 
			ORDER BY	A.PeriodStart , 
						AccountSk ; 

			;WITH cteDuplicates
			AS(	/*PK/Unique constraints are not enforced so...*/ 
				SELECT	PeriodStart, PeriodEnd, AccountSk, BusinessUnitSk, 
						RN = ROW_NUMBER()
								OVER(
									PARTITION BY PeriodStart, PeriodEnd, AccountSk, BusinessUnitSk 
									ORDER BY	PeriodStart, PeriodEnd
								)
				FROM	dbo.FactAccountBusinessUnitTarget T
			)
			DELETE	FROM cteDuplicates	
			WHERE	RN > 1 ; 

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