CREATE   
	PROCEDURE Internal.usp_Update_ResourceMonthlyTargetDays 
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 

AS
BEGIN
	SET NOCOUNT ON; 
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	Groundhog day 
	Logic lifted from Datawarehouse.[Kimble].[vw_Resource3_Target_AllDays]

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceMonthlyTargetDays]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceMonthlyTargetDays]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceMonthlyTargetDays]')
	EXEC Internal.usp_Update_ResourceMonthlyTargetDays @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	SELECT * FROM [Internal].[ResourceMonthlyTargetDays] ORDER BY PeriodStartDate; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DECLARE @CrederaUKBu VARCHAR(18) = (SELECT	Id 
												FROM	lh_SilverLayer.Kantata.HISTORY_BusinessUnit 
												WHERE	[Name] = 'Credera UK' AND _crda_ActiveToDateTime = '9999-12-31 23:59:59' AND _crda_isDeleted = 1 );


			DROP TABLE IF EXISTS #RsrcDays ; 

			/*Resource3Target 
			VIEW [Kimble].[vw_Resource3_DaysSummary] - Target_AllDays*/
			SELECT		 PeriodStartDate	= TP.KimbleOne__StartDate__c
						,PeriodEndDate		= TP.KimbleOne__EndDate__c
						,BusinessUnitBk		= ISNULL(BU.Id , @CrederaUKBu)
						,AnalysisDimension	= AD.[Name] 
						,AnalysisFact		=	CASE 
																/* NumberOfBusinessDays				Company*/ 
													WHEN AF.Id = 'a0ED000000tiX3pMAE' AND AD.Id IN ('a0DD000000B4H56MAF') 
														THEN	'TargetBusinessDays'
																/* NumberOfOtherDays				Company*/ 
													WHEN AF.Id = 'a0E3z00000tbtJAEAY' AND AD.Id IN ('a0DD000000B4H56MAF') 
														THEN	'TargetOtherDays'
																/* NumberOfHolidayDays				Business Unit*/ 
													WHEN AF.Id = 'a0E3z00000ve7fXEAQ' AND AD.Id IN ('a0DD000000ia99sMAA') 
														THEN	'TargetHolidaysDays'
																/* NumberOfTrainingDays				Company*/ 
													WHEN AF.Id = 'a0E3z00000ve7fSEAQ' AND AD.Id IN ('a0DD000000B4H56MAF') 
														THEN	'TargetTrainingDays'
													ELSE 
														NULL 
												END 
						,TargetAmount		= PA.KimbleOne__TargetAmount__c
			INTO #RsrcDays 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis	PA  

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisDimension	AD 	ON  AD.Id	= PA.KimbleOne__AnalysisDimension__c
																				AND AD._crda_isDeleted			= 0
																				AND	AD._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisFact		AF  ON	AF.Id	= PA.KimbleOne__AnalysisFact__c
																			AND AF._crda_isDeleted			= 0
																			AND	AF._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod		TP 	ON  TP.Id	= PA.KimbleOne__TimePeriod__c
																			AND TP._crda_isDeleted			= 0 
																			AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_BusinessUnit		BU	ON	BU.Id			= PA.KimbleOne__BusinessUnit__c 
																			AND BU._crda_isDeleted			= 0 
																			AND	BU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
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
			AND			PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'; 


			TRUNCATE TABLE Internal.ResourceMonthlyTargetDays;

			INSERT INTO Internal.ResourceMonthlyTargetDays
			(
				PeriodStartDate , 
				PeriodEndDate , 
				BusinessUnitBk , 
				TargetBusinessDays , 
				TargetTrainingDays , 
				TargetHolidaysDays , 
				TargetOtherDays , 
				_crda_CreatedExecutionId , 
				_crda_CreatedDateTime
			)
			SELECT	 PVT.PeriodStartDate 
					,PVT.PeriodEndDate 
					,ISNULL(PVT.BusinessUnitBk, 'UnknownRecord') 
					,TargetBusinessDays	= SUM(ISNULL(PVT.TargetBusinessDays , 0 ))
					,TargetTrainingDays	= SUM(ISNULL(PVT.TargetTrainingDays , 0 ))
					,TargetHolidaysDays	= SUM(ISNULL(PVT.TargetHolidaysDays , 0 ))
					,TargetOtherDays	= SUM(ISNULL(PVT.TargetOtherDays , 0 ))
					,@_ExecutionId 
					,GETUTCDATE()
			FROM	#RsrcDays Src
			PIVOT (
				MAX(TargetAmount)  
				FOR AnalysisFact IN ([TargetBusinessDays], [TargetTrainingDays], [TargetHolidaysDays], [TargetOtherDays])  
			) PVT 
			GROUP BY
					 PVT.PeriodStartDate 
					,PVT.PeriodEndDate 
					,PVT.BusinessUnitBk
			ORDER BY 
					 PVT.PeriodStartDate 
					,PVT.BusinessUnitBk ;

			/*Unique constraints are not enforced so...*/
			;WITH cteDups
			AS( 
				SELECT	PeriodStartDate, BusinessUnitBk 
						,RN =	ROW_NUMBER() 
								OVER (
									PARTITION BY	PeriodStartDate, BusinessUnitBk
									ORDER BY		PeriodStartDate, BusinessUnitBk 
								)
				FROM	Internal.ResourceMonthlyTargetDays T
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