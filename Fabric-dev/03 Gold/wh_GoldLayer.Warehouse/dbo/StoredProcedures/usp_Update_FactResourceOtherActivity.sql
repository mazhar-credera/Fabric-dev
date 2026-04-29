CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactResourceOtherActivity
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceOtherActivity]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceOtherActivity]' )
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceOtherActivity]' )
	EXEC dbo.usp_Update_FactResourceOtherActivity @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactResourceOtherActivity ; --89500
	SELECT COUNT(1) FROM dbo.FactResourceOtherActivity WHERE CsrActivity >0;
	SELECT COUNT(1) FROM dbo.FactResourceOtherActivity WHERE InterviewActivity>0;
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME = '20000101',	/*Groundhog Day*/
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow	DATETIME2= GETUTCDATE() ;
	DECLARE	@FutureDate	DATE = DATEADD(MONTH, 4, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Csr ;
			DROP TABLE IF EXISTS #Interview ;

			/*External/Internal CSR*/
			SELECT
				 PeriodStartDate= CAST(CP.KimbleOne__StartDate__c AS DATE) 
				,PeriodEndDate	= CAST(CP.KimbleOne__EndDate__c AS DATE) 
				,ResourceSk		= R.ResourceSK
				,CsrStartDate	= MIN(CAST(TP.KimbleOne__StartDate__c AS DATE) )
				,CsrEndDate		= MAX(CAST(TP.KimbleOne__EndDate__c AS DATE) )

				,CsrHours		= SUM(CAST(TE.KimbleOne__EntryUnits__c  AS DECIMAL(5,2)))
				,CsrDays		= SUM(CAST(TE.KimbleOne__EntryUnits__c /8  AS DECIMAL(5,2)))

				,IsExternalCsr	= SUM(IIF(TE.KimbleOne__CategoryCombination__c LIKE ('External CSR%'), 1, 0))
				,Category		= MAX(TE.KimbleOne__CategoryCombination__c )
				,CsrType		= MAX(X.CsrType )
				,CsrPartOfCredAcademy	= MAX(X.CsrPartOfCredAcademy ) 
				,CsrNameCharityOrgn		= MAX(X.CsrNameCharityOrgn )
				,CsrCostRate			= MAX(AA.KimbleOne__CostRate__c )
				,CsrRevenueRate			= MAX(AA.KimbleOne__RevenueRate__c )
			INTO #Csr 
			FROM    lh_SilverLayer.Kantata.HISTORY_TimeEntry	TE 
			INNER JOIN dbo.DimResource			R	ON	R.ResourceBk	= TE.KimbleOne__Resource__c 
													AND R.IsCurrent		= 1 

			INNER JOIN lh_SilverLayer.Kantata.HISTORY_TimePeriod	TP	ON	TP.Id	= TE.KimbleOne__TimePeriod__c 
														AND	TP._crda_isDeleted			= 0  
														AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	CP 	ON	CP.Id				= TP.KimbleOne__ForecastingTimePeriod__c
														AND CP._crda_isDeleted			= 0  
														AND	CP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			INNER JOIN lh_SilverLayer.Kantata.HISTORY_ActivityAssignment AA	ON	AA.Id	= TE.KimbleOne__ActivityAssignment__c 
															AND AA._crda_isDeleted			= 0  
															AND	AA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			OUTER APPLY (
				SELECT	CsrType				= TRIM(MAX(IIF(SS.Ordinal = 1, [value], null))) ,
						CsrPartOfCredAcademy= TRIM(MAX(IIF(SS.Ordinal = 2, [value], null))) , 
						CsrNameCharityOrgn	= TRIM(MAX(IIF(SS.Ordinal = 3, [value], null)))
				FROM	string_split(TE.KimbleOne__CategoryCombination__c, '-', 1) SS 
			) X

			WHERE	(TE.KimbleOne__CategoryCombination__c LIKE 'External CSR%' 
						OR	TE.KimbleOne__CategoryCombination__c LIKE 'Internal CSR%' )
			AND		TE._crda_isDeleted			= 0     
			AND		TE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			GROUP BY
				  CAST(CP.KimbleOne__StartDate__c AS DATE) 
				, CAST(CP.KimbleOne__EndDate__c AS DATE) 
				, R.ResourceSK ; 


			/*Interviews Related*/
			SELECT
				 PeriodStartDate= CAST(CP.KimbleOne__StartDate__c AS DATE) 
				,PeriodEndDate	= CAST(CP.KimbleOne__EndDate__c AS DATE) 
				,ResourceSk		= R.ResourceSK

				,InteviewDateConducted	= MIN(TS.KimbleOne__TimePeriodStartDate__c)
				,InterviewHours			= SUM(CAST(TE.KimbleOne__EntryUnits__c  AS DECIMAL(5,2)))
				,InterviewDays			= SUM(CAST(TE.KimbleOne__EntryUnits__c /8  AS DECIMAL(5,2)))

				,InterviewCategory		= MAX(TE.KimbleOne__CategoryCombination__c )
			INTO #Interview 
			FROM		lh_SilverLayer.Kantata.HISTORY_ResourcedActivity	RA  

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Timesheet	TS	ON	TS.KimbleOne__ResourcedActivity__c = RA.Id
														AND TS._crda_isDeleted			= 0 
														AND	TS._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimeEntry	TE	ON	TE.KimbleOne__Timesheet__c	= TS.Id
														AND TE._crda_isDeleted			= 0 
														AND	TE._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN lh_SilverLayer.Kantata.HISTORY_TimePeriod		TP	ON	TP.Id	= TE.KimbleOne__TimePeriod__c 
														AND	TP._crda_isDeleted			= 0  
														AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod	CP 	ON	CP.Id				= TP.KimbleOne__ForecastingTimePeriod__c
														AND CP._crda_isDeleted			= 0  
														AND	CP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			INNER JOIN dbo.DimResource				R	ON	R.ResourceBk	= TE.KimbleOne__Resource__c 
														AND R.IsCurrent		= 1 

			WHERE	RA.Id				= 'a1a4K000000GIRBQA4' /* People > Interviewing */ 
			AND		RA._crda_isDeleted	= 0  
			AND		RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			GROUP BY
				 CAST(CP.KimbleOne__StartDate__c AS DATE) 
				,CAST(CP.KimbleOne__EndDate__c AS DATE) 
				,R.ResourceSK ;
				
			/*SELECT * FROM #Interview WHERE ResourceSK = 27 order by PeriodStartDate*/

			TRUNCATE TABLE dbo.FactResourceOtherActivity ; 

			INSERT INTO dbo.FactResourceOtherActivity
			( 
				 FactResourceOtherActivitySk 
				,ResourceSk
				,PeriodStartDate
				,PeriodEndDate

				/*External/Internal CSR*/
				,CsrActivity
				,CsrStartDate
				,CsrEndDate
				,CsrHours
				,CsrDays
				,IsExternalCsr
				,CsrPartOfCredAcademy
				,CsrNameCharityOrgn
				,CsrCostRate
				,CsrRevenueRate

				/*Interviews Related*/
				,InterviewActivity
				,InterviewHours
				,InterviewDays
				,InterviewCategory
				,InteviewDateConducted

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY RAD.ResourceSk, RAD.PeriodStartDate) 
				,RAD.ResourceSk
				,RAD.PeriodStart
				,RAD.PeriodEnd

				/*External/Internal CSR*/
				,IIF(C.CsrHours IS NOT NULL, 1, 0)
				,C.CsrStartDate
				,C.CsrEndDate
				,ISNULL(C.CsrHours, 0)
				,ISNULL(C.CsrDays, 0)
				,ISNULL(C.IsExternalCsr, 0)
				,ISNULL(C.CsrPartOfCredAcademy, NULL)
				,ISNULL(C.CsrNameCharityOrgn, NULL)
				,ISNULL(C.CsrCostRate, 0)
				,ISNULL(C.CsrRevenueRate, 0)

				/*Interviews Related*/
				,IIF(I.InterviewHours IS NOT NULL, 1, 0)
				,ISNULL(I.InterviewHours, 0)
				,ISNULL(I.InterviewDays, 0)
				,ISNULL(I.InterviewCategory, NULL)
				,ISNULL(I.InteviewDateConducted, NULL)

				,@_ExecutionId 
				,GETUTCDATE() 
			FROM  dbo.FN_GetResourceAllDates (@FutureDate) RAD

			LEFT JOIN #Csr			C	ON	C.PeriodStartDate	= RAD.PeriodStart
										AND	C.PeriodEndDate		= RAD.PeriodEnd
										AND	C.ResourceSk		= RAD.ResourceSk 

			LEFT JOIN #Interview	I	ON	I.PeriodStartDate	= RAD.PeriodStart
										AND	I.PeriodEndDate		= RAD.PeriodEnd
										AND	I.ResourceSk		= RAD.ResourceSk 

			ORDER BY 
				 RAD.ResourceSk
				,RAD.PeriodStart ;


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