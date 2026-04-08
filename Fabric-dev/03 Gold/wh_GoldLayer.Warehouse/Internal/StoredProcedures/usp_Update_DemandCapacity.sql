CREATE  
	PROCEDURE Internal.usp_Update_DemandCapacity
	--Default Parameters
	@ExecutionId	INT = -1073, 
	@Watermark		VARCHAR(255) = '20000101', 
	@ProcessId		INT = 1 
WITH RECOMPILE 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DemandCapacity]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DemandCapacity]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DemandCapacity]')
	EXEC Internal.usp_Update_DemandCapacity @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT count(1) FROM Internal.DemandCapacity ; /*1486*/
	SELECT count(1), sum(iif(DemandRef is null, 1, 0)) FROM Internal.DemandCapacity ; /*1486	124*/
	SELECT count(1), DemandCapacityType FROM Internal.DemandCapacity GROUP BY DemandCapacityType; /*1486*/
	
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow	DATETIME2	= GETUTCDATE() ;
	DECLARE	@Today		DATE	= CONVERT(DATE, @TimeNow) ;
	DECLARE @FutureDate DATE	= DATEADD(YEAR, 3, @Today);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #CURRENTrole ; 

			/*CURRENTrole*/
			SELECT
				 AA.ActivityAssignmentBk 
				,DemandCapacityType					= 'CURRENTrole' /*Demand*/
				,PeriodStartDate					= CAST(AA.DemandStart AS DATE)
				,PeriodEndDate						= CAST(AA.DemandEnd  AS DATE) 
				,PeriodStartMonthEnd				= EOMONTH(CAST(AA.DemandStart AS DATE))
				,PeriodEndMonthEnd					= EOMONTH(CAST(AA.DemandEnd AS DATE))
				
				,AA.ResourceBk 
				,AA.ResourcedActivityBk 
				,AA.ActivityAssignmentDemandBk 
				,AA.ActivityDemandStatusBk 
				,AA.CandidateStatusBk 
				,AA.ActivityAssgnRoleBk 
				,AA.ActivityDeliveryGroupBk 
				,AA.DeliveryGroupAccountBk 
				,AA.ResourcedActivityBusinessUnitBk  
				,ReferenceDataBk					= AA.ActivityDemandStatusBk		/*ReferenceDataBk*//*[Status], Domain*/
				,AA.ResourcingStatusBk												/*ResourcingStatus*/

				,AA.UtilisationPercentage 

				,AA.TotalActualCost 
				,AA.ForecastP1Cost  
				,AA.ForecastP2Cost  
				,AA.ForecastP3Cost  

				,AA.TotalActualUsage 
				,AA.ForecastP1Usage 
				,AA.ForecastP2Usage 
				,AA.ForecastP3Usage 

				,ForecastRevenueRate			= AA.RevenueRate
				,AA.TotalActualRevenue 
				,AA.ForecastP1Revenue 
				,AA.ForecastP2Revenue 
				,AA.ForecastP3Revenue 
				,[Status]						= ISNULL(RD.[Name], '') 
				,DeliveryElementProbability		= ISNULL(EFE.KimbleOne__Probability__c , -9)
				,DeliveryGroupForecastStatusName= ISNULL(EFG.[Name] , '') 

				,AA.DeliveryGroupForecastStatusBk 
				,AA.ResourceDeliveryElementBk 
				,AA.DemandRef
				,xRN						= ROW_NUMBER() 
												OVER(
														PARTITION BY	AA.DemandRef 
														ORDER BY		HR.[Name] DESC, AA.DemandStart DESC
													) 
			INTO #CURRENTrole 
			FROM		Internal.DemandActivity			AA 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Resource			HR	ON	HR.Id				= AA.ResourceBk  
																			AND HR._crda_isDeleted = 0
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus 	EFG	ON	EFG.Id				= AA.DeliveryGroupForecastStatusBk /*DeliveryGroup*/
																			AND EFG._crda_isDeleted = 0
																			AND	EFG._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus 	EFE	ON	EFE.Id				= AA.ResourceDeliveryElementBk   /*DeliveryElement*/
																			AND EFE._crda_isDeleted = 0
																			AND	EFE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ReferenceData	RD	ON	RD.Id				= AA.ActivityDemandStatusBk 
																			AND RD._crda_isDeleted = 0
																			AND	RD._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			WHERE	ISNULL(AA.CandidateStatusBk , '')	<> 'a1RD0000002PmaqMAC'	/*Declined*/
			AND		(ISNULL(RD.[Name], '') IN ('Open', 'Fulfilled') 
						OR	(
								ISNULL(RD.[Name], '') ='CandidatesProposed'		/*a1RD0000002PmbIMAS*/
								AND LEFT(HR.[Name],8) <> '#Generic'
							)
					)
			AND		ISNULL(RD.KimbleOne__Domain__c , '')= 'AssignmentDemandStatus'
			AND		NOT (
						ISNULL(HR.[Name],'') LIKE '#Generic Associate%' 
							OR ISNULL(HR.[Name],'') LIKE '#Generic Partner%' 
								OR ISNULL(HR.[Name],'') LIKE '#Generic Nearshore%'
						) 
				/*Exclude leavers*/	
			AND		COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, @FutureDate)	> @Today 
			; 
			/*SELECT * FROM #CURRENTrole ORDER BY ResourceBk, PeriodStartDate*/


			TRUNCATE TABLE Internal.DemandCapacity ;

			INSERT INTO Internal.DemandCapacity
			( 
				 ActivityAssignmentBk 
				,DemandCapacityType	
				,PeriodStartDate 
				,PeriodEndDate 
				,PeriodStartMonthEnd 
				,PeriodEndMonthEnd 
				
				,ResourceBk 
				,ResourcedActivityBk 
				,ActivityAssignmentDemandBk 
				,ActivityDemandStatusBk 
				,CandidateStatusBk 
				,ActivityAssgnRoleBk 
				,ActivityDeliveryGroupBk 
				,DeliveryGroupAccountBk 
				,ResourcedActivityBusinessUnitBk  
				,ReferenceDataBk 	/*ReferenceDataBk*//*[Status], Domain*/
				,ResourcingStatusBk	/*ResourcingStatus*/

				,DeliveryGroupForecastStatusBk 
				,ResourceDeliveryElementBk 

				,UtilisationPercentage 

				,TotalActualCost 
				,ForecastP1Cost  
				,ForecastP2Cost  
				,ForecastP3Cost  

				,TotalActualUsage 
				,ForecastP1Usage 
				,ForecastP2Usage 
				,ForecastP3Usage 

				,ForecastRevenueRate 
				,TotalActualRevenue 
				,ForecastP1Revenue 
				,ForecastP2Revenue 
				,ForecastP3Revenue 

				,DemandRef

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
				/*CURRENTrole*/
			SELECT
				 X.ActivityAssignmentBk 
				,X.DemandCapacityType	
				,X.PeriodStartDate 
				,X.PeriodEndDate 
				,X.PeriodStartMonthEnd 
				,X.PeriodEndMonthEnd 
				
				,X.ResourceBk 
				,X.ResourcedActivityBk 
				,X.ActivityAssignmentDemandBk 
				,X.ActivityDemandStatusBk 
				,X.CandidateStatusBk 
				,X.ActivityAssgnRoleBk 
				,X.ActivityDeliveryGroupBk 
				,X.DeliveryGroupAccountBk 
				,X.ResourcedActivityBusinessUnitBk  
				,X.ReferenceDataBk 	/*ReferenceDataBk*//*[Status], Domain*/
				,X.ResourcingStatusBk	/*ResourcingStatus*/

				,X.DeliveryGroupForecastStatusBk 
				,X.ResourceDeliveryElementBk 

				,X.UtilisationPercentage 

				,X.TotalActualCost 
				,X.ForecastP1Cost  
				,X.ForecastP2Cost  
				,X.ForecastP3Cost  

				,X.TotalActualUsage 
				,X.ForecastP1Usage 
				,X.ForecastP2Usage 
				,X.ForecastP3Usage 

				,X.ForecastRevenueRate 
				,X.TotalActualRevenue 
				,X.ForecastP1Revenue 
				,X.ForecastP2Revenue 
				,X.ForecastP3Revenue 

				,X.DemandRef

				,@_ExecutionId  
				,GETUTCDATE() 
			FROM(
				SELECT	* 
				FROM	#CURRENTrole 
				WHERE	xRN = 1 
				AND		[Status] = 'Open'

				UNION ALL 

				SELECT	* 
				FROM	#CURRENTrole 
				WHERE	[Status] = 'CandidatesProposed'

				UNION ALL

				SELECT	* 
				FROM	#CURRENTrole 
				WHERE	[Status]			= 'Fulfilled'
				AND		DeliveryGroupForecastStatusName	<> '9. Lost (0%)' 
				AND		xRN = 1
				AND	NOT	([Status] = 'Fulfilled' AND DeliveryElementProbability = 100) 
			) X 
			WHERE	X.PeriodEndDate >= CAST(GETUTCDATE() AS DATE) ; 

			/*#FUTURErole*/
			INSERT INTO Internal.DemandCapacity
			( 
				 ActivityAssignmentBk 
				,DemandCapacityType	
				,PeriodStartDate 
				,PeriodEndDate 
				,PeriodStartMonthEnd 
				,PeriodEndMonthEnd 
				
				,ResourceBk 
				,ResourcedActivityBk 
				,ActivityAssignmentDemandBk 
				,ActivityDemandStatusBk 
				,CandidateStatusBk 
				,ActivityAssgnRoleBk 
				,ActivityDeliveryGroupBk 
				,DeliveryGroupAccountBk 
				,ResourcedActivityBusinessUnitBk  
				,ReferenceDataBk 	/*ReferenceDataBk*//*[Status], Domain*/
				,ResourcingStatusBk	/*ResourcingStatus*/

				,DeliveryGroupForecastStatusBk 
				,ResourceDeliveryElementBk 

				,UtilisationPercentage 

				,TotalActualCost 
				,ForecastP1Cost  
				,ForecastP2Cost  
				,ForecastP3Cost  

				,TotalActualUsage 
				,ForecastP1Usage 
				,ForecastP2Usage 
				,ForecastP3Usage 

				,ForecastRevenueRate 
				,TotalActualRevenue 
				,ForecastP1Revenue 
				,ForecastP2Revenue 
				,ForecastP3Revenue 

				,DemandRef 

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
				/*#FUTURErole*/
			SELECT
				 AA.ActivityAssignmentBk 
				,DemandCapacityType					= 'FUTURErole' 
				,PeriodStartDate					= CAST(AA.DemandStart AS DATE)
				,PeriodEndDate						= CAST(AA.DemandEnd  AS DATE) 
				,PeriodStartMonthEnd				= EOMONTH(CAST(AA.DemandStart AS DATE))
				,PeriodEndMonthEnd					= EOMONTH(CAST(AA.DemandEnd AS DATE))
				
				,AA.ResourceBk 
				,AA.ResourcedActivityBk 
				,AA.ActivityAssignmentDemandBk 
				,AA.ActivityDemandStatusBk 
				,AA.CandidateStatusBk 
				,AA.ActivityAssgnRoleBk	
				,AA.ActivityDeliveryGroupBk 
				,AA.DeliveryGroupAccountBk 
				,AA.ResourcedActivityBusinessUnitBk  
				,ReferenceDataBk					= AA.ActivityDemandStatusBk		/*ReferenceDataBk*//*[Status], Domain*/
				,AA.ResourcingStatusBk												/*ResourcingStatus*/

				,AA.DeliveryGroupForecastStatusBk 
				,AA.ResourceDeliveryElementBk 

				,AA.UtilisationPercentage 

				,AA.TotalActualCost 
				,AA.ForecastP1Cost  
				,AA.ForecastP2Cost  
				,AA.ForecastP3Cost  

				,AA.TotalActualUsage 
				,AA.ForecastP1Usage 
				,AA.ForecastP2Usage 
				,AA.ForecastP3Usage 

				,ForecastRevenueRate		= AA.RevenueRate
				,AA.TotalActualRevenue 
				,AA.ForecastP1Revenue 
				,AA.ForecastP2Revenue 
				,AA.ForecastP3Revenue 

				,AA.DemandRef 

				,@_ExecutionId  
				,GETUTCDATE() 

			FROM	Internal.DemandActivity		AA 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id			= AA.ResourceBk  
																AND HR._crda_isDeleted = 0
																AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			WHERE	AA.UtilisationPercentage > 0
			AND		ISNULL(AA.ResourcedActivityTypeBk,'')		= 'a1ZD0000000hnnuMAA'	/*Delivery*/ 
			AND		ISNULL(AA.CandidateStatusBk,'')				<> 'a1RD0000002PmaqMAC'	/*Declined*/ 
			AND		ISNULL(AA.DeliveryGroupForecastStatusBk, '')<> 'a0nD0000001yjIiIAI'	/*9. Lost (0%)*/ 
				/*Roles that haven't started yet*/ 
			AND		AA.DemandStart >= CAST(@TimeNow AS DATE) 
				/*Exclude leavers*/	
			AND		COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, @FutureDate)	> @Today 
			;


			/*#NoDemandRef*/
			INSERT INTO Internal.DemandCapacity
			( 
				 ActivityAssignmentBk 
				,DemandCapacityType	
				,PeriodStartDate 
				,PeriodEndDate 
				,PeriodStartMonthEnd 
				,PeriodEndMonthEnd 
				
				,ResourceBk 
				,ResourcedActivityBk 
				,ActivityAssignmentDemandBk 
				,ActivityDemandStatusBk 
				,CandidateStatusBk 
				,ActivityAssgnRoleBk 
				,ActivityDeliveryGroupBk 
				,DeliveryGroupAccountBk 
				,ResourcedActivityBusinessUnitBk  
				,ReferenceDataBk 	/*ReferenceDataBk*//*[Status], Domain*/
				,ResourcingStatusBk	/*ResourcingStatus*/

				,DeliveryGroupForecastStatusBk 
				,ResourceDeliveryElementBk 

				,UtilisationPercentage 

				,TotalActualCost 
				,ForecastP1Cost  
				,ForecastP2Cost  
				,ForecastP3Cost  

				,TotalActualUsage 
				,ForecastP1Usage 
				,ForecastP2Usage 
				,ForecastP3Usage 

				,ForecastRevenueRate 
				,TotalActualRevenue 
				,ForecastP1Revenue 
				,ForecastP2Revenue 
				,ForecastP3Revenue 

				,DemandRef 

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
				/*#FUTURErole*/
			SELECT
				 AA.ActivityAssignmentBk 
				,DemandCapacityType					= 'NoDemandRef' 
				,PeriodStartDate					= CAST(AA.DemandStart AS DATE)
				,PeriodEndDate						= CAST(AA.DemandEnd  AS DATE) 
				,PeriodStartMonthEnd				= EOMONTH(CAST(AA.DemandStart AS DATE))
				,PeriodEndMonthEnd					= EOMONTH(CAST(AA.DemandEnd AS DATE))
				
				,AA.ResourceBk 
				,AA.ResourcedActivityBk 
				,AA.ActivityAssignmentDemandBk 
				,AA.ActivityDemandStatusBk 
				,AA.CandidateStatusBk 
				,AA.ActivityAssgnRoleBk	
				,AA.ActivityDeliveryGroupBk 
				,AA.DeliveryGroupAccountBk 
				,AA.ResourcedActivityBusinessUnitBk  
				,ReferenceDataBk					= AA.ActivityDemandStatusBk		/*ReferenceDataBk*//*[Status], Domain*/
				,AA.ResourcingStatusBk												/*ResourcingStatus*/

				,AA.DeliveryGroupForecastStatusBk 
				,AA.ResourceDeliveryElementBk 

				,AA.UtilisationPercentage 

				,AA.TotalActualCost 
				,AA.ForecastP1Cost  
				,AA.ForecastP2Cost  
				,AA.ForecastP3Cost  

				,AA.TotalActualUsage 
				,AA.ForecastP1Usage 
				,AA.ForecastP2Usage 
				,AA.ForecastP3Usage 

				,ForecastRevenueRate		= AA.RevenueRate
				,AA.TotalActualRevenue 
				,AA.ForecastP1Revenue 
				,AA.ForecastP2Revenue 
				,AA.ForecastP3Revenue 

				,AA.DemandRef 

				,@_ExecutionId  
				,GETUTCDATE() 

			FROM	Internal.DemandActivity			AA 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource		HR	ON	HR.Id				= AA.ResourceBk  
																		AND HR._crda_isDeleted = 0
																		AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	DE	ON	DE.Id				= AA.ResourceDeliveryElementBk  
																			AND DE._crda_isDeleted = 0
																			AND	DE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			WHERE	AA.DemandRef IS NULL
			AND		DE.KimbleOne__Reference__c IS NOT NULL 
			AND		ISNULL(AA.CandidateStatusBk,'')				<> 'a1RD0000002PmaqMAC'	/*Declined*/ 
			AND		NOT (
						ISNULL(HR.[Name],'') LIKE '#Generic Associate%' 
							OR ISNULL(HR.[Name],'') LIKE '#Generic Partner%' 
								OR ISNULL(HR.[Name],'') LIKE '#Generic Nearshore%'
						) 
				/*Exclude leavers*/	
			AND		COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, @FutureDate)	> @Today 
			; 


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