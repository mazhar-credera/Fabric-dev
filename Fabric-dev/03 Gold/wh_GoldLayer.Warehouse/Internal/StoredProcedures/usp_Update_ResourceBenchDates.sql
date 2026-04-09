CREATE   
	PROCEDURE Internal.usp_Update_ResourceBenchDates
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceBenchDates]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceBenchDates]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_ResourceBenchDates]')
	EXEC Internal.usp_Update_ResourceBenchDates @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM Internal.ResourceBenchDates ; --763 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME = CAST(@Watermark AS DATETIME2) ,
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow	DATETIME2= GETUTCDATE() ;
	DECLARE	@PastDate	DATE ; 
	DECLARE	@FutureDate	DATE ; 

	SELECT	@PastDate	= PastDate ,
			@FutureDate	= FutureDate
	FROM	Tools.FN_GetPastAndFutureDates (-3, 2);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #ExplodedOutResourceDates ; 
			DROP TABLE IF EXISTS #Fcd; 
			DROP TABLE IF EXISTS #FactCurrentDemand; 
			DROP TABLE IF EXISTS #FactFutureDemand; 
			DROP TABLE IF EXISTS #ExplodedOutEngagements ; 

			SELECT	EmploymentStart = BU.DateFrom,
					PeriodStart		= DD.[Date] , 
					PeriodStartSk	= DD.DateKey , 
					BU.ResourceBk 
			INTO #ExplodedOutResourceDates 
			FROM	Internal.DimDate		DD 
			CROSS APPLY ( 
				SELECT	ResourceBk	= HR.Id,
						DateFrom	= CAST(MAX(HR.KimbleOne__StartDate__c) AS DATE),
						DateTo		= CAST(MAX(COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c,@FutureDate)) AS DATE)
				FROM	lh_SilverLayer.Kantata.HISTORY_Resource	HR	
				WHERE	HR._crda_isDeleted = 0 
				AND		HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				--AND		HR.Id = 'a1X8e000001foz4EAA'
				GROUP BY 
					HR.Id 
			)	BU 
			WHERE	DD.IsNonWorkDay = 0 
			AND		DD.[Date] >= @PastDate AND DD.[Date] <= BU.DateTo 
			ORDER BY ResourceBk, PeriodStart 
			; 

			/*#FactCurrentDemand*/
			SELECT
				 DemandStart					= CAST(AA.DemandStart AS DATE)
				,DemandEnd						= CAST(AA.DemandEnd AS DATE) 
				,AA.ResourceBk 
				,DeliveryElementProbability		= ISNULL(EFE.KimbleOne__Probability__c , -9)
				,AA.UtilisationPercentage 
				,[Status]						= ISNULL(RD.[Name], '') 
				,DeliveryGroupForecastStatusName= ISNULL(EFG.[Name] , '') 
				,xRN							= ROW_NUMBER() 
													OVER(
															PARTITION BY	AA.DemandRef 
															ORDER BY		DR.[Name] DESC, AA.DemandStart DESC
														) 
			INTO #Fcd 
			FROM		Internal.DemandActivity					AA 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	DR  ON  DR.Id				= AA.ResourceBk
																	AND DR._crda_isDeleted	= 0
																	AND	DR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	DE  ON  DE.Id				= AA.ResourceDeliveryElementBk
																			AND DE._crda_isDeleted	= 0
																			AND	DE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	EFG	ON  EFG.Id				= AA.DeliveryGroupForecastStatusBk /*DeliveryGroup*/
																			AND EFG._crda_isDeleted = 0
																			AND	EFG._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	EFE	ON  EFE.Id				= DE.KimbleOne__ForecastStatus__c /*DeliveryElement*/
																			AND EFE._crda_isDeleted = 0
																			AND	EFE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ReferenceData	RD	ON	RD.Id				= AA.ActivityDemandStatusBk 
																			AND RD._crda_isDeleted	= 0
																			AND	RD._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 


			WHERE	ISNULL(AA.CandidateStatusBk , '')	<> 'a1RD0000002PmaqMAC'	/*Declined*/
			AND		(ISNULL(RD.[Name], '') IN ('Open', 'Fulfilled') 
						OR	(
								ISNULL(RD.[Name], '') ='CandidatesProposed' 
								AND LEFT(DR.[Name],8) <> '#Generic'
							)
					)
			AND		ISNULL(RD.KimbleOne__Domain__c , '')= 'AssignmentDemandStatus'
			AND		NOT (
						ISNULL(DR.[Name],'') LIKE '#Generic Associate%' 
							OR ISNULL(DR.[Name],'') LIKE '#Generic Partner%' 
								OR ISNULL(DR.[Name],'') LIKE '#Generic Nearshore%'
						) ; 


			SELECT	X.ResourceBk, 
					X.DemandStart, X.DemandEnd, 
					X.DeliveryElementProbability, 
					X.UtilisationPercentage 
			INTO #FactCurrentDemand 
			FROM(
				SELECT	*
				FROM	#Fcd 
				WHERE	xRN = 1 
				AND		[Status] = 'Open'

				UNION ALL 

				SELECT	*
				FROM	#Fcd 
				WHERE	[Status] = 'CandidatesProposed'

				UNION ALL

				SELECT	*
				FROM	#Fcd 
				WHERE	[Status]			= 'Fulfilled'
				AND		DeliveryGroupForecastStatusName	<> '9. Lost (0%)' 
				AND		xRN = 1
				AND	NOT	([Status] = 'Fulfilled' AND DeliveryElementProbability = 100) 
			) X ;
			/*SELECT * FROM #ExplodedOutEngagements ORDER BY ResourceBk, InWorkDate*/


			/*#FactFutureDemand*/ 
			SELECT	 DemandStart			= CAST(AA.KimbleOne__StartDate__c AS DATE)
					,DemandEnd				= CAST(AA.KimbleOne__ForecastP3EndDate__c  AS DATE) 
					,ResourceBk				= AA.KimbleOne__Resource__c 
					,Probability			= DG_FS.KimbleOne__Probability__c 
					,UtilisationPercentage	= AA.KimbleOne__UtilisationPercentage__c 
			INTO #FactFutureDemand 
			FROM		(
							SELECT	RN=ROW_NUMBER()OVER
									(
										PARTITION BY	A.KimbleOne__Resource__c, A.KimbleOne__ResourcedActivity__c, A.KimbleOne__DeliveryGroup__c
										ORDER BY		A._crda_ActiveFromDateTime DESC 
									), *
							FROM	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment A	
							WHERE	A._crda_isDeleted			= 0 
							AND		A._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
						) AA 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id				= AA.KimbleOne__ResourcedActivity__c 
																				AND	AA.RN				= 1 
																				AND	RA._crda_isDeleted	= 0 
																				AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	DG	ON	DG.Id				= AA.KimbleOne__DeliveryGroup__c
																			AND	DG._crda_isDeleted	= 0 
																			AND	DG._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	DG_FS	ON	DG_FS.Id				= DG.KimbleOne__ForecastStatus__c
																				AND	DG_FS._crda_isDeleted	= 0 
																				AND	DG_FS._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Resource		R	ON  R.Id				= AA.KimbleOne__Resource__c
																		AND	R._crda_isDeleted	= 0 
																		AND	R._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			LEFT JOIN	(
						SELECT	RN=ROW_NUMBER()OVER
								(
									PARTITION BY	D.KimbleOne__DeliveryGroup__c
									ORDER BY		D._crda_ActiveFromDateTime DESC 
								)
								,*
						FROM	lh_SilverLayer.Kantata.HISTORY_DeliveryElement D
						WHERE	D._crda_isDeleted			= 0 
						AND		D._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
						)							DE	ON	DE.KimbleOne__DeliveryGroup__c = DG.Id
														AND	DE.RN = 1 

			LEFT JOIN	(
						SELECT	
							SortOrder	=
										CASE FS.[Name]
											WHEN '9. Lost (0%)'			THEN 0
											WHEN '1. Lead (1%)'			THEN 1
											WHEN '2. Qualify (10%)'		THEN 2
											WHEN '3. Solutions (25%)'	THEN 3
											WHEN '3. Possible (40%)'	THEN 3
											WHEN '4. Propose (50%)'		THEN 4 
											WHEN '4. Probable (60%)'	THEN 4
											WHEN '5. Negotiate (75%)'	THEN 5
											WHEN '6. Verbal Win (90%)'	THEN 6
											WHEN '7. Firm (100%)'		THEN 7
											WHEN 'Working at Risk (100%)'	THEN 7
										END 
								,*
						FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus FS 
						WHERE	FS._crda_isDeleted			= 0 
						AND		FS._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
						)							DE_FS	ON	DE_FS.Id = DE.KimbleOne__ForecastStatus__c 


			WHERE		AA.[KimbleOne__UtilisationPercentage__c]			> 0 
			AND			ISNULL(AA.KimbleOne__CandidateStatus__c,'')			<> 'a1RD0000002PmaqMAC' /*Declined*/
			AND			ISNULL(RA.KimbleOne__ResourcedActivityType__c,'')	= 'a1ZD0000000hnnuMAA'  /*Delivery*/

			AND			(
							(AA.KimbleOne__StartDate__c >= R.KimbleOne__StartDate__c)
								AND	( AA.KimbleOne__StartDate__c >= CAST(GETDATE() AS DATE)
										OR 	(CAST(GETDATE() AS DATE)) BETWEEN AA.KimbleOne__StartDate__c AND AA.KimbleOne__ForecastP3EndDate__c
									) 
						) 
			AND			ISNULL(DG_FS.Id,'') <> 'a0nD0000001yjIiIAI' /*9. Lost (0%)*/



			/*#ExplodedOutEngagements*/
			SELECT	 X.ResourceBk, X.InWorkDate--, IsCurrentDemand
					,Probability			= IIF(SUM(X.Probability) > 100, 100, SUM(X.Probability))
					,UtilisationPercentage	= IIF(SUM(X.UtilisationPercentage) > 100, 100, SUM(X.UtilisationPercentage))
					,TotalEngagements		= COUNT(1) 
			INTO #ExplodedOutEngagements 
			FROM(
				/*#FactCurrentDemand*/
				SELECT	 ResourceBk, InWorkDate = D.[Date]
						,Probability=IIF(DeliveryElementProbability < 0 , 0, DeliveryElementProbability)
						,F.UtilisationPercentage
						,IsCurrentDemand = 1 
				FROM	#FactCurrentDemand	F
				CROSS APPLY Internal.DimDate		D 
				WHERE	D.[Date] >= F.DemandStart AND D.[Date] <= F.DemandEnd 
				AND		D.IsNonWorkDay = 0 
				UNION ALL 
				SELECT	 ResourceBk, FutureDemandDate = D.[Date] 
						,Probability	= IIF(Probability < 0 , 0, Probability)
						,FD.UtilisationPercentage 
						,IsCurrentDemand = 0 
				FROM	#FactFutureDemand	FD
				CROSS APPLY Internal.DimDate		D 
				WHERE	D.[Date] >= FD.DemandStart AND D.[Date] <= FD.DemandEnd 
				AND		D.IsNonWorkDay = 0 
				AND		(@PastDate BETWEEN FD.DemandStart AND FD.DemandEnd
					OR	@FutureDate BETWEEN FD.DemandStart AND FD.DemandEnd ) 
			) X 
			WHERE X.InWorkDate BETWEEN @PastDate AND @FutureDate
			GROUP BY X.ResourceBk, X.InWorkDate ; 


			TRUNCATE TABLE Internal.ResourceBenchDates ;

			/*
				Gaps and Islands to generate Start and End dates for Bench dates 
					of continuous dates (including those that straddle weekends and bank holidays
			*/
			;WITH cteIdentifyGaps
			AS(
			SELECT	 F.ResourceBk, F.PeriodStart, R.InWorkDate 
					,R.UtilisationPercentage
					,R.TotalEngagements
					,OnBench	= IIF
									(
										R.InWorkDate IS NULL				/*No assignments whatsoever*/
											OR R.UtilisationPercentage < 94	/*not fully utilised*/
										, 1, 0
									)
					,RN			= ROW_NUMBER() 
										OVER( 
											PARTITION BY F.ResourceBk
											ORDER BY	 F.PeriodStart
										) 
					,Gaps		= ROW_NUMBER() 
										OVER( 
											PARTITION BY F.ResourceBk , IIF(R.InWorkDate IS NOT NULL, 1, 0)
											ORDER BY	 F.PeriodStart
										) 

				FROM	#ExplodedOutResourceDates F 
				LEFT JOIN #ExplodedOutEngagements R	ON	R.ResourceBk = F.ResourceBk 
													AND	R.InWorkDate = F.PeriodStart 
			) , cteIdentifyIslandsOfAbsences
			AS(
				SELECT	F.* 
						,Islands = RN-Gaps
				FROM	cteIdentifyGaps F
				WHERE	F.OnBench = 1	/*on the bench*/
			) 
			INSERT INTO Internal.ResourceBenchDates 
			(
				 ResourceBk 
				,BenchStartDate 
				,BenchEndDate 
				,NumberOfDays
				,UtilisationPercentage
				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			) 
			SELECT
				 I.ResourceBk 
				,BenchStartDate			= MIN(I.PeriodStart)
				,BenchEndDate			= MAX(I.PeriodStart)
				,NumberOfDays			= COUNT(1) 
				,UtilisationPercentage	= CAST(ISNULL(I.UtilisationPercentage,0) AS DECIMAL(9,3))
				,@_ExecutionId  
				,GETUTCDATE() 
			FROM	cteIdentifyIslandsOfAbsences I 
			--WHERE ISNULL(I.UtilisationPercentage,0) = 0
			GROUP BY I.ResourceBk, I.Islands, ISNULL(I.UtilisationPercentage,0) ; 

			/*Exclude Generic Resources*/
			DELETE	E 
			FROM	Internal.ResourceBenchDates	E 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	DR  ON  DR.Id				= E.ResourceBk
													AND DR._crda_isDeleted = 0
													AND	DR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
			WHERE	(DR.[Name] LIKE '#%' OR DR.[Name] LIKE '@%') ;
			/*SELECT * FROM Internal.ResourceBenchDates WHERE ResourceBk = 'a1X3z000003w4BjEAI'*/

			/*PK/Unique constraints are not enforced so...*/
			;WITH cteDups
			AS( 
				SELECT	ResourceBk, BenchStartDate 
						,RN =	ROW_NUMBER() 
								OVER (
									PARTITION BY	ResourceBk, BenchStartDate
									ORDER BY		BenchStartDate 
								)
				FROM	Internal.ResourceBenchDates T
			) 
			DELETE FROM cteDups WHERE RN > 1 ;


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(@TimeNow), @_Watermark),121) ;
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