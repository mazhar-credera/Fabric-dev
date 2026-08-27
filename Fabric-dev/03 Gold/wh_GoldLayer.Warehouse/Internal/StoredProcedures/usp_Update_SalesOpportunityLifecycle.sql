CREATE  
	PROCEDURE Internal.usp_Update_SalesOpportunityLifecycle
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 

AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_SalesOpportunityLifecycle]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_SalesOpportunityLifecycle]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_SalesOpportunityLifecycle]')
	EXEC Internal.usp_Update_SalesOpportunityLifecycle @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId 
	SELECT count(1) FROM [Internal].[SalesOpportunityLifecycle] ; 
	--truncate table [Internal].[SalesOpportunityLifecycle]
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121) ,
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY 

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			;WITH cteSalesOps
			AS(
				SELECT	OpportunityBk				= S.Id , 
						AccountBk					= S.KimbleOne__Account__c , 
						RelatedOpportunityBk		= S.Related_Opportunity__c , 
						OpportunityStageBk 			= S.KimbleOne__OpportunityStage__c , 
						OpportunitySourceBk			= S.KimbleOne__OpportunitySource__c , 
						MarketingCampaignBk			= S.KimbleOne__MarketingCampaign__c , 
						SectorBk 					= S.SectorId__c , 
						ProposedDeliveryProgramBk	= S.Proposed_Delivery_Program__c , 
						CommercialSignoffBk 		= S.CommercialSignoff__c , 
						OriginatorBk				= S.Originator__c , 
						OwnerId						= S.OwnerId ,

						LinkToProposal				= S.LinkToProposal__c , 
						TypeofWork					= S.TypeofWork__c , 
						CloseDate					= S.KimbleOne__CloseDate__c , 
						ResponseRequiredDate		= S.KimbleOne__CloseDate__c , 
						WonLostReason				= S.KimbleOne__WonLostReason__c	, 
						ClosePlanAccurate			= NULL , 
						StandardRateCardUsed		= NULL , 
						OrganicGrowth				= NULL , 
						ProposalBk					= S.KimbleOne__Proposal__c , 
						ForecastStatusBk			= S.KimbleOne__ForecastStatus__c , 
						BidStatus					= S.BidStatus__c ,	
						BidFramework				= S.BidFramework__c ,
						BidPQQDueDate				= S.BidPQQDueDate__c,
						BidPQQStatus				= S.BidPQQStatus__c ,
						S._crda_ActiveFromDateTime 

				FROM	lh_SilverLayer.Kantata.HISTORY_SalesOpportunity	S 

				LEFT JOIN lh_SilverLayer.Kantata.HISTORY_ForecastStatus	F	ON	F.Id	= S.KimbleOne__ForecastStatus__c 
																			AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																			AND	F._crda_isDeleted		 = 0 

				WHERE	S._crda_isDeleted		 = 0 
				AND		S._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
				AND		S._crda_ActiveFromDateTime >= @_Watermark  

				UNION ALL 

				SELECT	O.Id , 
						AccountBk					= O.AccountId , 
						RelatedOpportunityBk 		= CAST(NULL AS VARCHAR(18)) , 
						OpportunityStageBk 			= CAST(NULL AS VARCHAR(18)) , 
						OpportunitySourceBk			= CAST(NULL AS VARCHAR(18)) , 
						MarketingCampaignBk			= O.CampaignId , 
						SectorBk					= SC.Id , 
						ProposedDeliveryProgramBk	= O.KC_Proposed_Delivery_Program__c , 
						CommercialSignoffBk			= CAST(NULL AS VARCHAR(18)) , 
						OriginatorBk				= O.KC_Originator__c , 
						O.OwnerId ,

						LinkToProposal				= O.KC_Link_To_Proposal__c , 
						TypeofWork					= O.[Type] , 
						O.CloseDate , 
						ResponseRequiredDate		= O.CloseDate , 
						WonLostReason				= O.Reason_Lost__c , 
						ClosePlanAccurate			= O.Close_Plan_Accurate__c , 
						StandardRateCardUsed		= O.Standard_Rate_Card_Used__c , 
						OrganicGrowth				= O.Organic_Growth__c , 
						ProposalBk					= O.KimbleOne__Proposal__c , 
						ForecastStatusBk			= F.Id , 
						BidStatus					= NULL , 
						BidFramework				= NULL , 
						BidPQQDueDate				= NULL , 
						BidPQQStatus				= NULL , 
						O._crda_ActiveFromDateTime 

				FROM		lh_SilverLayer.Kantata.HISTORY_Opportunity	O 
				LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account		A	ON	A.Id	= O.AccountId 
															AND	A._crda_ActiveToDateTime= '9999-12-31 23:59:59'
															AND	A._crda_isDeleted		 = 1 

				LEFT JOIN ( /*ForecastStatus.Name values changed Dec 2025*/
					SELECT	Id, [Name], _crda_ActiveToDateTime , 
							RN=ROW_NUMBER()OVER(
									PARTITION BY [Name] 
									ORDER BY _crda_ActiveToDateTime)
					FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus F 
					WHERE	F._crda_isDeleted = 1 
				)										FH	ON	FH.[Name] = O.StageName 
															AND	FH.RN = 1

				LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Account		AC	ON	AC.Id					= O.AccountId  
																			AND	AC._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																			AND	AC._crda_isDeleted		 = 0 

				LEFT JOIN lh_SilverLayer.Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= FH.Id 
																			AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																			AND	F._crda_isDeleted		= 0 

				LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Sector			SC	ON	SC.[Name]				= A.SectorName__c 
																			AND	SC._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																			AND	SC._crda_isDeleted		 = 0  

				WHERE	O._crda_isDeleted		 = 0  
				AND		O._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
				AND		O._crda_ActiveFromDateTime >= @_Watermark  
		
			)	
			SELECT	 SalesOpportunityBk			= SO.OpportunityBk  
					,SalesOpportunitytDateTime	= SO._crda_ActiveFromDateTime
					,AccountBusinessUnitBk		= AC.KimbleOne__BusinessUnit__c 
					,AccountBk					= AC.Id 
					,ProposalBusinessUnitBk		= PS.KimbleOne__BusinessUnit__c 
					,ProposalBk					= SO.ProposalBk 
					,RelatedSalesOpportunityBk	= SO.RelatedOpportunityBk 
					,ForecastStatusBk			= SO.ForecastStatusBk  
					,OpportunityStageBk			= SO.OpportunityStageBk 
					,OpportunitySourceBk		= SO.OpportunitySourceBk 
					,SectorBk					= SO.SectorBk   
					,PropositionBk				= PS.KimbleOne__Proposition__c 
					,MarketingCampaignBk		= SO.MarketingCampaignBk  
					,ProposedDeliveryProgramBk	= SO.ProposedDeliveryProgramBk 
					,OriginatorBk				= SO.OriginatorBk 
					,CommercialSignOffBk		= SO.CommercialSignoffBk
					,SalesOpportunityOwnerBk	= SO.OwnerId 
					,ProposalOwnerBk			= PS.OwnerId  
					,CloseDate					= SO.CloseDate 
					,AcceptanceDate				= PS.KimbleOne__AcceptanceDate__c 
					,ResponseRequiredDate		= SO.ResponseRequiredDate 
					,EarliestStartDate			= PS.earliestStartDate__c 
					,LatestEndDate				= PS.latestEndDate__c 
					,DeliveryStartDate			= PS.KimbleOne__DeliveryStartDate__c 
					,CurrencyIsoCode			= ISNULL(PS.CurrencyIsoCode , 'ZZZ')
					,WonLostReason				= ISNULL(SO.WonLostReason , '') 
					,BidStatus					= SO.BidStatus 
					,BidFramework				= SO.BidFramework
					,BidPQQDueDate				= CAST(SO.BidPQQDueDate AS DATE) 
					,BidPQQStatus				= SO.BidPQQStatus 
					,ContractRevenue			= ISNULL(PS.KimbleOne__ContractRevenue__c , 0) 
					,ContractMargin				= ISNULL(PS.KimbleOne__ContractMargin__c , 0)  
					,ContractCost				= ISNULL(PS.KimbleOne__ContractCost__c , 0) 
					,ContractMarginAmount		= ISNULL(PS.KimbleOne__ContractMarginAmount__c , 0) 
					,ContractMarginPercentage	= ISNULL(PS.KimbleOne__ContractMargin__c , 0) 
					,WeightedContractRevenue	= ISNULL(PS.KimbleOne__WeightedContractRevenue__c , 0) 
					,IsForecastedAtDetailedLevel= IIF(ISNULL(PS.KimbleOne__ForecastAtDetailedLevel__c , 0 ) = 0, 0 , 1) 
					,DetailedLevelContractCost				= ISNULL(PS.KimbleOne__DetailedLevelContractCost__c , 0) 
					,DetailedLevelContractRevenue			= ISNULL(PS.KimbleOne__DetailedLevelContractRevenue__c , 0) 
					,DetailedLevelWeightedContractRevenue	= ISNULL(PS.KimbleOne__DetailedLevelWeightedContractRevenue__c , 0) 
					,HighLevelContractCost				= ISNULL(PS.KimbleOne__HighLevelContractCost__c , 0) 
					,HighLevelContractRevenue			= ISNULL(PS.KimbleOne__HighLevelContractRevenue__c , 0)
					,HighLevelWeightedContractRevenue	= ISNULL(PS.KimbleOne__HighLevelWeightedContractRevenue__c , 0) 
					,ProposalCost						= ISNULL(PS.KimbleOne__ProposalCost__c , 0) 
					,ProposalExpenseCost				= ISNULL(PS.KimbleOne__ProposalExpensesCost__c , 0) 
					,ProposalMarginAmount				= ISNULL(PS.KimbleOne__ProposalMarginAmount__c , 0) 
					,ProposalMarginPercentage			= ISNULL(PS.KimbleOne__ProposalMargin__c , 0) 
					,ProposalUsageCost					= ISNULL(PS.KimbleOne__ProposalUsageCost__c , 0)
					,DiscountAmount						= ISNULL(PS.KimbleOne__Discount__c , 0) 
					,DiscountPercentage					= ISNULL(PS.KimbleOne__DiscountPercentage__c , 0) 
					,DMWElementIsWAR					= IIF(ISNULL(PS.DMW_Element_is_WAR__c , 0 ) = 0, 0, 1) 

			INTO #Source 
			FROM	cteSalesOps			 SO	

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account	AC	ON	AC.Id = SO.AccountBk 
																AND	AC._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																AND	AC._crda_isDeleted = 0 

			LEFT  JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	PS	ON	PS.OpportunityId = SO.OpportunityBk  
																	AND	PS._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																	AND	PS._crda_isDeleted = 0 ; 



	--		select rn = row_number()OVER(partition by SalesOpportunityBk, SalesOpportunitytDateTime order by SalesOpportunitytDateTime),	* 
	--		from #source order by SalesOpportunitytDateTime
			TRUNCATE TABLE Internal.SalesOpportunityLifecycle ; 

			INSERT INTO Internal.SalesOpportunityLifecycle 
			( 
				 SalesOpportunityBk
				,SalesOpportunitytDateTime
				,AccountBusinessUnitBk
				,AccountBk
				,ProposalBusinessUnitBk
				,ProposalBk
				,RelatedSalesOpportunityBk
				,ForecastStatusBk
				,OpportunityStageBk
				,OpportunitySourceBk
				,SectorBk
				,PropositionBk
				,MarketingCampaignBk
				,ProposedDeliveryProgramBk
				,OriginatorBk
				,CommercialSignOffBk
				,SalesOpportunityOwnerBk
				,ProposalOwnerBk
				,CloseDate
				,AcceptanceDate
				,ResponseRequiredDate
				,EarliestStartDate
				,LatestEndDate
				,DeliveryStartDate
				,CurrencyIsoCode
				,WonLostReason
				,BidStatus
				,BidFramework
				,BidPQQDueDate
				,BidPQQStatus
				,ContractRevenue
				,ContractMargin
				,ContractCost
				,ContractMarginAmount
				,ContractMarginPercentage
				,WeightedContractRevenue
				,IsForecastedAtDetailedLevel
				,DetailedLevelContractCost
				,DetailedLevelContractRevenue
				,DetailedLevelWeightedContractRevenue
				,HighLevelContractCost
				,HighLevelContractRevenue
				,HighLevelWeightedContractRevenue
				,ProposalCost
				,ProposalExpenseCost
				,ProposalMarginAmount
				,ProposalMarginPercentage
				,ProposalUsageCost
				,DiscountAmount
				,DiscountPercentage
				,DMWElementIsWAR
				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 SRC.SalesOpportunityBk
				,SRC.SalesOpportunitytDateTime 
				,SRC.AccountBusinessUnitBk
				,SRC.AccountBk
				,SRC.ProposalBusinessUnitBk 
				,SRC.ProposalBk
				,SRC.RelatedSalesOpportunityBk
				,SRC.ForecastStatusBk
				,SRC.OpportunityStageBk
				,SRC.OpportunitySourceBk
				,SRC.SectorBk
				,SRC.PropositionBk
				,SRC.MarketingCampaignBk
				,SRC.ProposedDeliveryProgramBk
				,SRC.OriginatorBk
				,SRC.CommercialSignOffBk
				,SRC.SalesOpportunityOwnerBk
				,SRC.ProposalOwnerBk
				,SRC.CloseDate
				,SRC.AcceptanceDate
				,SRC.ResponseRequiredDate
				,SRC.EarliestStartDate
				,SRC.LatestEndDate
				,SRC.DeliveryStartDate
				,SRC.CurrencyIsoCode
				,SRC.WonLostReason
				,SRC.BidStatus
				,SRC.BidFramework
				,SRC.BidPQQDueDate
				,SRC.BidPQQStatus
				,SRC.ContractRevenue
				,SRC.ContractMargin
				,SRC.ContractCost
				,SRC.ContractMarginAmount
				,SRC.ContractMarginPercentage
				,SRC.WeightedContractRevenue
				,SRC.IsForecastedAtDetailedLevel
				,SRC.DetailedLevelContractCost
				,SRC.DetailedLevelContractRevenue
				,SRC.DetailedLevelWeightedContractRevenue
				,SRC.HighLevelContractCost
				,SRC.HighLevelContractRevenue
				,SRC.HighLevelWeightedContractRevenue
				,SRC.ProposalCost
				,SRC.ProposalExpenseCost
				,SRC.ProposalMarginAmount
				,SRC.ProposalMarginPercentage
				,SRC.ProposalUsageCost
				,SRC.DiscountAmount
				,SRC.DiscountPercentage
				,SRC.DMWElementIsWAR
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM #Source SRC 
			ORDER BY 
				SalesOpportunityBk, SalesOpportunitytDateTime ;

			/*PK/Unique constraints are not enforced so...*/
			;WITH cteDups
			AS( 
				SELECT	 SalesOpportunityBk, SalesOpportunitytDateTime 
						,RN =	ROW_NUMBER() 
								OVER (
									PARTITION BY	SalesOpportunityBk, SalesOpportunitytDateTime 
									ORDER BY		SalesOpportunityBk, SalesOpportunitytDateTime 
								)
				FROM	Internal.SalesOpportunityLifecycle T
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