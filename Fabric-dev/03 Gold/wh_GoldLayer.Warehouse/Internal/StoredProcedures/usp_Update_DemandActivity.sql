CREATE  
	PROCEDURE Internal.usp_Update_DemandActivity
	--Default Parameters 
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
--WITH RECOMPILE 
AS 
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM Meta.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DemandActivity]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM Meta.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DemandActivity]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM Meta.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DemandActivity]')
	EXEC Internal.usp_Update_DemandActivity @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId
	SELECT count(1) FROM Internal.DemandActivity ; /*152919*/
	--TRUNCATE TABLE Internal.DemandActivity ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = '20000101',
			@_ProcessId		INT		= @ProcessId, 
			@TimeNow		DATETIME2= GETUTCDATE() ;

	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35)	= CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			SELECT	
				 ActivityAssignmentBk		= AA.Id 
				,ActivityAssignmentDemandBk	= AA.KimbleOne__ActivityAssignmentDemand__c 
				,DemandStart				= AA.KimbleOne__StartDate__c 
				,DemandEnd					= AA.KimbleOne__ForecastP3EndDate__c 
				,DemandStartMonthEnd		= EOMONTH(AA.KimbleOne__StartDate__c,0)	
				,DemandEndMonthEnd			= EOMONTH(AA.KimbleOne__ForecastP3EndDate__c,0) 

				,EarliestTimeEntryDate		= AA.KimbleOne__EarliestTimeEntryDate__c 
				,LatestTimeEntryDate		= AA.KimbleOne__LatestTimeEntryDate__c
				,ForecastP1EndDate			= AA.KimbleOne__ForecastP1EndDate__c  
				,ForecastP2EndDate			= AA.KimbleOne__ForecastP2EndDate__c 
				,ForecastP3EndDate			= AA.KimbleOne__ForecastP3EndDate__c 

				,ResourceBk					= AA.KimbleOne__Resource__c 
				,IncludeInRollUp			= AA.KimbleOne__IncludeInRollUp__c 
				,ResourcedActivityBk		= AA.KimbleOne__ResourcedActivity__c 

				,ActivityAssgnRoleBk		= AA.KimbleOne__ActivityRole__c 
				,ActivityAssignmentDemandRole= AAD.ActivityRole__c
				,ActivityRolePracticeBk		= AR.Practice__c 
				,CandidateStatusBk			= AA.KimbleOne__CandidateStatus__c 

				,ResourceLocationBk			= R.KimbleOne__Location__c 
				,ActivityLocationBk			= AA.KimbleOne__Location__c 
				,ActivityDeliveryGroupBk	= AA.KimbleOne__DeliveryGroup__c 
				,DeliveryGroupAccountBk		= DG.KimbleOne__Account__c 
				,DeliveryGroupForecastStatusBk	= DG.KimbleOne__ForecastStatus__c
				,ActivityDemandStatusBk		= AAD.KimbleOne__Status__c /*HISTORY_ReferenceData*/
				,ResourcingStatusBk			= AAD.KimbleOne__ResourcingStatus__c 

				,CurrencyIsoCode			= AA.CurrencyIsoCode 
				,RevenueRate				= AA.KimbleOne__ForecastRevenueRate__c 

				,TotalActualCost			= AA.KimbleOne__TotalActualCost__c  
				,ForecastP1Cost				= AA.KimbleOne__ForecastP1Cost__c 
				,ForecastP2Cost				= AA.KimbleOne__ForecastP2Cost__c 
				,ForecastP3Cost				= AA.KimbleOne__ForecastP3Cost__c 

				,TotalActualRevenue			= AA.KimbleOne__TotalActualRevenue__c  
				,ForecastP1Revenue			= AA.KimbleOne__ForecastP1Revenue__c 
				,ForecastP2Revenue			= AA.KimbleOne__ForecastP2Revenue__c 
				,ForecastP3Revenue			= AA.KimbleOne__ForecastP3Revenue__c 

				,TotalActualUsage			= AA.KimbleOne__TotalActualUsage__c 
				,ForecastP1Usage			= AA.KimbleOne__ForecastP1Usage__c 
				,ForecastP2Usage			= AA.KimbleOne__ForecastP2Usage__c 
				,ForecastP3Usage			= AA.KimbleOne__ForecastP3Usage__c 

				,BaselineCost				= AA.KimbleOne__BaselineCost__c 
				,BaselineMargin				= AA.KimbleOne__BaselineMargin__c 
				,BaselineMarginAmount		= AA.KimbleOne__BaselineMarginAmount__c 
				,BaselineRevenue			= AA.KimbleOne__BaselineRevenue__c 
				,BaselineUsage				= AA.KimbleOne__BaselineUsage__c 
				,BaselineUtilisationPercentage	= AA.KimbleOne__BaselineUtilisationPercentage__c 

				,AssignmentPercentage			= AA.KimbleOne__AssignmentPercentage__c 
				,DefaultCostRatePercentage		= AA.KimbleOne__DefaultCostRatePercentage__c 
				,DefaultRevenueRatePercentage	= AA.KimbleOne__DefaultRevenueRatePercentage__c 
				,DiscountPercentage				= AA.KimbleOne__DiscountPercentage__c 
				,UtilisationPercentage			= AA.KimbleOne__UtilisationPercentage__c 

				,ResourcedActivityBusinessUnitBk= RA.KimbleOne__BusinessUnit__c 
				,ResourcedActivityTypeBk		= RA.KimbleOne__ResourcedActivityType__c 
				,ActivityGroup					= RA.Activity_Group__c
				,ResourceDeliveryElementBk		= RA.KimbleOne__DeliveryElement__c 
				/*ActivityName=ISNULL(RA.KimbleOne__FullName__c, DG.DisplayName__c) */
				,DemandRef						= AAD.Demand_Ref__c 
				,ActivityAssignmentLogNotes		= AA.KimbleOne__LongNotes__c 
				,AA._crda_ActiveFromDateTime 
				,AD._crda_HASH

			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_ActivityAssignment		AA  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand AAD	ON	AAD.Id				= AA.KimbleOne__ActivityAssignmentDemand__c
																					AND AAD._crda_isDeleted	= 0	
																					AND	AAD._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
						
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource		R	ON	R.Id				= AA.KimbleOne__Resource__c
																		AND	R._crda_isDeleted	= 0 
																		AND	R._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ActivityRole	AR	ON  AR.Id				= AA.KimbleOne__ActivityRole__c
																		AND AR._crda_isDeleted	= 0
																		AND	AR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity	RA  ON  RA.Id			= AA.KimbleOne__ResourcedActivity__c
																			AND RA._crda_isDeleted	= 0
																			AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	DG	ON  DG.Id			= AA.KimbleOne__DeliveryGroup__c
																		AND	DG._crda_isDeleted	= 0 
																		AND	DG._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			CROSS APPLY (
			SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								 AA.KimbleOne__ActivityAssignmentDemand__c 
								,CONVERT(VARCHAR(35), AA.KimbleOne__ForecastP3EndDate__c , 121) 
								,CONVERT(VARCHAR(35), EOMONTH(AA.KimbleOne__ForecastP3EndDate__c,0) , 121) 

								,CONVERT(VARCHAR(35), AA.KimbleOne__EarliestTimeEntryDate__c , 121) 
								,CONVERT(VARCHAR(35), AA.KimbleOne__LatestTimeEntryDate__c , 121) 
								,CONVERT(VARCHAR(35), AA.KimbleOne__ForecastP1EndDate__c , 121) 
								,CONVERT(VARCHAR(35), AA.KimbleOne__ForecastP2EndDate__c , 121) 
								,CONVERT(VARCHAR(35), AA.KimbleOne__ForecastP3EndDate__c , 121) 

								,AA.KimbleOne__Resource__c 
								,AA.KimbleOne__IncludeInRollUp__c 
								,AA.KimbleOne__ResourcedActivity__c 

								,AA.KimbleOne__ActivityRole__c 
								,AAD.ActivityRole__c
								,AR.Practice__c 
								,AA.KimbleOne__CandidateStatus__c 

								,R.KimbleOne__Location__c 
								,AA.KimbleOne__Location__c 
								,AA.KimbleOne__DeliveryGroup__c 
								,DG.KimbleOne__Account__c 
								,DG.KimbleOne__ForecastStatus__c
								,AAD.KimbleOne__Status__c /*HISTORY_ReferenceData*/
								,AAD.KimbleOne__ResourcingStatus__c 

								,AA.CurrencyIsoCode 
								,AA.KimbleOne__ForecastRevenueRate__c 

								,AA.KimbleOne__TotalActualCost__c  
								,AA.KimbleOne__ForecastP1Cost__c 
								,AA.KimbleOne__ForecastP2Cost__c 
								,AA.KimbleOne__ForecastP3Cost__c 

								,AA.KimbleOne__TotalActualRevenue__c  
								,AA.KimbleOne__ForecastP1Revenue__c 
								,AA.KimbleOne__ForecastP2Revenue__c 
								,AA.KimbleOne__ForecastP3Revenue__c 

								,AA.KimbleOne__TotalActualUsage__c 
								,AA.KimbleOne__ForecastP1Usage__c 
								,AA.KimbleOne__ForecastP2Usage__c 
								,AA.KimbleOne__ForecastP3Usage__c 

								,AA.KimbleOne__BaselineCost__c 
								,AA.KimbleOne__BaselineMargin__c 
								,AA.KimbleOne__BaselineMarginAmount__c 
								,AA.KimbleOne__BaselineRevenue__c 
								,AA.KimbleOne__BaselineUsage__c 
								,AA.KimbleOne__BaselineUtilisationPercentage__c 

								,AA.KimbleOne__AssignmentPercentage__c 
								,AA.KimbleOne__DefaultCostRatePercentage__c 
								,AA.KimbleOne__DefaultRevenueRatePercentage__c 
								,AA.KimbleOne__DiscountPercentage__c 
								,AA.KimbleOne__UtilisationPercentage__c 

								,RA.KimbleOne__BusinessUnit__c 
								,RA.KimbleOne__ResourcedActivityType__c 
								,RA.Activity_Group__c
								,RA.KimbleOne__DeliveryElement__c 
								/*ActivityName=ISNULL(RA.KimbleOne__FullName__c, DG.DisplayName__c) */
								,AAD.Demand_Ref__c 
								,AA.KimbleOne__LongNotes__c 
							) 
					) AS VARBINARY(16)) AS _crda_HASH
				)  AD  
			WHERE	AA._crda_ActiveFromDateTime > @_Watermark 
			AND		AA._crda_isDeleted			= 0 
			AND		AA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' ; 
			/*AND		ISNULL(AA.KimbleOne__CandidateStatus__c,'') <> 'a1RD0000002PmaqMAC' ; Declined*/ 



			TRUNCATE TABLE Internal.DemandActivity ;

			INSERT INTO Internal.DemandActivity
			( 
				 ActivityAssignmentBk

				,DemandStart
				,DemandEnd
				,DemandStartSk
				,DemandEndSk

				,ActivityAssignmentDemandBk
				,ResourceBk

				,DemandStartMonthEnd
				,DemandEndMonthEnd
				,DemandStartMonthEndSk
				,DemandEndMonthEndSk

				,EarliestTimeEntryDate
				,LatestTimeEntryDate
				,ForecastP1EndDate
				,ForecastP2EndDate
				,ForecastP3EndDate
				,IncludeInRollUp
				,ResourcedActivityBk
				,ActivityAssgnRoleBk
				,ActivityAssignmentDemandRole
				,ActivityRolePracticeBk
				,CandidateStatusBk
				,ResourceLocationBk
				,ActivityLocationBk
				,ActivityDeliveryGroupBk
				,DeliveryGroupAccountBk 
				,DeliveryGroupForecastStatusBk 
				,ActivityDemandStatusBk
				,ResourcingStatusBk
				,CurrencyIsoCode
				,RevenueRate
				,TotalActualCost
				,ForecastP1Cost
				,ForecastP2Cost
				,ForecastP3Cost
				,TotalActualRevenue
				,ForecastP1Revenue
				,ForecastP2Revenue
				,ForecastP3Revenue
				,TotalActualUsage
				,ForecastP1Usage
				,ForecastP2Usage
				,ForecastP3Usage
				,BaselineCost
				,BaselineMargin
				,BaselineMarginAmount
				,BaselineRevenue
				,BaselineUsage
				,BaselineUtilisationPercentage
				,AssignmentPercentage
				,DefaultCostRatePercentage
				,DefaultRevenueRatePercentage
				,DiscountPercentage
				,UtilisationPercentage
				,ResourcedActivityBusinessUnitBk
				,ResourcedActivityTypeBk
				,ActivityGroup
				,ResourceDeliveryElementBk
				,DemandRef 
				,ActivityAssignmentLogNotes 
				,_crda_Hash
				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
				,_crda_UpdatedExecutionId
				,_crda_UpdatedDateTime
			)
			SELECT
				 SRC.ActivityAssignmentBk

				,SRC.DemandStart
				,SRC.DemandEnd
				,(CONVERT([int],CONVERT([varchar](8),DemandStart,(112))))
				,(CONVERT([int],CONVERT([varchar](8),DemandEnd,(112))))

				,SRC.ActivityAssignmentDemandBk
				,SRC.ResourceBk

				,SRC.DemandStartMonthEnd
				,SRC.DemandEndMonthEnd
				,(CONVERT([int],CONVERT([varchar](8),DemandStartMonthEnd,(112))))
				,(CONVERT([int],CONVERT([varchar](8),DemandEndMonthEnd,(112))))

				,SRC.EarliestTimeEntryDate
				,SRC.LatestTimeEntryDate
				,SRC.ForecastP1EndDate
				,SRC.ForecastP2EndDate
				,SRC.ForecastP3EndDate
				,SRC.IncludeInRollUp
				,SRC.ResourcedActivityBk
				,SRC.ActivityAssgnRoleBk
				,SRC.ActivityAssignmentDemandRole
				,SRC.ActivityRolePracticeBk
				,SRC.CandidateStatusBk
				,SRC.ResourceLocationBk
				,SRC.ActivityLocationBk
				,SRC.ActivityDeliveryGroupBk
				,SRC.DeliveryGroupAccountBk 
				,SRC.DeliveryGroupForecastStatusBk 
				,SRC.ActivityDemandStatusBk
				,SRC.ResourcingStatusBk
				,SRC.CurrencyIsoCode
				,SRC.RevenueRate
				,SRC.TotalActualCost
				,SRC.ForecastP1Cost
				,SRC.ForecastP2Cost
				,SRC.ForecastP3Cost
				,SRC.TotalActualRevenue
				,SRC.ForecastP1Revenue
				,SRC.ForecastP2Revenue
				,SRC.ForecastP3Revenue
				,SRC.TotalActualUsage
				,SRC.ForecastP1Usage
				,SRC.ForecastP2Usage
				,SRC.ForecastP3Usage
				,SRC.BaselineCost
				,SRC.BaselineMargin
				,SRC.BaselineMarginAmount
				,SRC.BaselineRevenue
				,SRC.BaselineUsage
				,SRC.BaselineUtilisationPercentage
				,SRC.AssignmentPercentage
				,SRC.DefaultCostRatePercentage
				,SRC.DefaultRevenueRatePercentage
				,SRC.DiscountPercentage
				,SRC.UtilisationPercentage
				,SRC.ResourcedActivityBusinessUnitBk
				,SRC.ResourcedActivityTypeBk
				,SRC.ActivityGroup
				,SRC.ResourceDeliveryElementBk
				,SRC.DemandRef 
				,SRC.ActivityAssignmentLogNotes 
				,SRC._crda_Hash

				,@_ExecutionId  
				,GETUTCDATE()
				,@_ExecutionId 
				,GETUTCDATE()
			FROM #Source SRC 

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Source S ;

			SELECT	InitialWatermark	= @strOldWatermark, 
					UpdatedWatermark	= @strNewWatermark ; 

		COMMIT;

	END TRY
	BEGIN CATCH
		ROLLBACK ;
		THROW;
	END CATCH ; 

	IF @@TRANCOUNT > 0 
		ROLLBACK; 

END;