CREATE  
	PROCEDURE dbo.usp_Update_FactAccountTarget
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactAccountTarget]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactAccountTarget]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactAccountBusinessUnitTarget]')
	EXEC dbo.usp_Update_FactAccountTarget @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactAccountTarget ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);


	BEGIN TRY

		BEGIN TRANSACTION 


			DROP TABLE IF EXISTS #FactAccountTarget ;
			TRUNCATE TABLE dbo.FactAccountTarget ;

			/*#FactAccountTarget*/
			SELECT	PeriodStartDate		= CAST(TP.KimbleOne__StartDate__c AS DATE) , 
					PeriodEndDate		= CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					AccountSk			= COALESCE(AC.AccountSk, -1) ,
					RevenueTargetAmount	= SUM(CAST(PA.KimbleOne__CorporateCurrencyTarget__c AS DECIMAL(18,2)))
			INTO #FactAccountTarget 

			FROM	lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
																		AND	TP._crda_isDeleted			= 0  
																		AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
																		AND PT._crda_isDeleted			= 0 
																		AND	PT.[Name]					= 'Month'
																		AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			LEFT JOIN	dbo.DimAccount					AC	ON	AC.AccountBk				= PA.KimbleOne__Account__c 
															AND	AC.IsCurrent				= 1	

			WHERE	PA._crda_isDeleted					= 0  
			AND		PA._crda_ActiveToDateTime			= '9999-12-31 23:59:59'  
			AND		PA._crda_ActiveFromDateTime			>= @_Watermark 
			AND		PA.KimbleOne__AnalysisDimension__c	= 'a0DD000000B4H55MAF'	--Account
			AND		PA.KimbleOne__AnalysisFact__c		= 'a0ED000000CxJIuMAN'	--Revenue
			GROUP BY 
					CAST(TP.KimbleOne__StartDate__c AS DATE) ,
					CAST(TP.KimbleOne__EndDate__c AS DATE) ,
					COALESCE(AC.AccountSk, -1) ;



			WITH cteAllDates
			AS(
				SELECT	PeriodStart		= D.[Date] , 
						PeriodStartSk	= D.DateSk , 
						PeriodEnd		= EOMONTH(D.[Date]) ,
						PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH(D.[Date]), 112) AS INT) 
				FROM	dbo.DimDate			D
				WHERE	DayNumberInMonth = 1 
				AND		D.[Date] <= DATEADD(MONTH, 12, GETUTCDATE())
			)
			INSERT INTO dbo.FactAccountTarget
			(	
			   PeriodStart
			  ,PeriodEnd
			  ,PeriodStartSk 
			  ,PeriodEndSk 
			  ,AccountSk
			  ,RevenueTargetAmount
			  ,_crda_CreatedExecutionId
			  ,_crda_CreatedDateTime
			  ,_crda_PK_JoinHash 
			)
			SELECT	A.PeriodStart ,
					A.PeriodEnd , 
					(CONVERT([int],CONVERT([varchar](8),PeriodStart,(112)))) , 
					(CONVERT([int],CONVERT([varchar](8),PeriodEnd,(112)))) , 
					AccountSk			= COALESCE(FS.AccountSk , -1) ,
					RevenueTargetAmount	= COALESCE(FS.RevenueTargetAmount ,0) ,
					@_ExecutionId ,
					GETUTCDATE() , 
					CAST (HASHBYTES('MD5', 
							CONCAT_WS('||', 
									A.PeriodStart, 
									A.PeriodEnd, 
									COALESCE(FS.AccountSk , -1) )
					) AS BINARY (16)) 

			FROM	cteAllDates				A 
			LEFT JOIN	#FactAccountTarget	FS	ON	FS.PeriodStartDate	= A.PeriodStart 
												AND	FS.PeriodEndDate	= A.PeriodEnd 

			ORDER BY	A.PeriodStart, 
						AccountSk ; 


			;WITH cteDuplicates
			AS(	/*PK/Unique constraints are not enforced so...*/ 
				SELECT	PeriodStart, PeriodEnd, AccountSk , 
						RN = ROW_NUMBER()
								OVER(
									PARTITION BY PeriodStart, PeriodEnd, AccountSk 
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