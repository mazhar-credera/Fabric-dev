CREATE   
	PROCEDURE dbo.usp_Update_DimSalesOpportunity
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSalesOpportunity]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSalesOpportunity]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSalesOpportunity]')
	EXEC dbo.usp_Update_DimSalesOpportunity @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimSalesOpportunity ORDER BY SalesOpportunitySk 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters 
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 

	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			TRUNCATE TABLE dbo.DimSalesOpportunity ; 

			INSERT INTO dbo.DimSalesOpportunity ( 
				SalesOpportunitySk, SalesOpportunityBk, [Name], [Description], AccountViewName, SOReference, LinkToProposal, ServiceProposition, 
					TypeofWork , CloseDate, ResponseRequiredDate, EarliestStartDate, LatestEndDate, UrlToKanataRecord, UrlToKanataDmwRecord, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT SalesOpportunitySk, SalesOpportunityBk, [Name], [Description], AccountViewName, SOReference, LinkToProposal, ServiceProposition, 
						TypeofWork , CloseDate, ResponseRequiredDate, EarliestStartDate, LatestEndDate, UrlToKanataRecord, UrlToKanataDmwRecord, 
							_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
								,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord', '', '', '', '', '', 
							'', NULL, NULL, NULL, NULL , '', '' , 
								'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
									,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	SalesOpportunitySk, SalesOpportunityBk, [Name], [Description], AccountViewName, SOReference, LinkToProposal, ServiceProposition, 
									TypeofWork , CloseDate, ResponseRequiredDate, EarliestStartDate, LatestEndDate, UrlToKanataRecord, UrlToKanataDmwRecord, 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimSalesOpportunity B 
				WHERE	B.SalesOpportunitySk = T.SalesOpportunitySk 
			) ; 


			SELECT	SalesOpportunityBk	= T.OpportunityId , 
					T.[Name], 
					[Description]		= ISNULL(LEFT(T.[Description],2000) , '') , 
					AccountViewName		= ISNULL(T.AccountViewName__c , '') , 
					SOReference			= ISNULL(T.SOReference , '' ) , 
					LinkToProposal		= ISNULL(T.LinkToProposal , '' ) , 
					ServiceProposition	= ISNULL(T.ServiceProposition, '') , 
					TypeofWork			= ISNULL(T.TypeofWork , '') , 
					CloseDate				= CONVERT(DATE, T.CloseDate, 120),
					ResponseRequiredDate	= CONVERT(DATE, T.ResponseRequiredDate, 120),
					EarliestStartDate		= CONVERT(DATE, T.EarliestStartDate, 120),
					LatestEndDate			= CONVERT(DATE, T.LatestEndDate, 120),
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					ProposalActiveFrom		= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime), 
					IsNewBusiness			= PA.IsNewBusiness ,
					DeliveryStatus			= T.ForecastStatusName , 
					DeliverySplit			= CASE ISNULL(T.ForecastStatusName, '')
													WHEN ''						THEN 'Ignore'
													WHEN '1. Lead (1%)'			THEN '1%'
													WHEN '2. Longshot (10%)'	THEN '10%'
													WHEN '2. Qualify (10%)'		THEN '10%'
													WHEN '3. Solutions (25%)'	THEN '25%'
													WHEN '3. Possible (40%)'	THEN '40%'
													WHEN '4. Propose (50%)'		THEN '50%'
													WHEN '4. Probable (60%)'	THEN '60%'
													WHEN '5. Negotiate (75%)'	THEN '75%'
													WHEN '5. Confident (90%)'	THEN '90%'
													WHEN '6. Verbal Win (90%)'	THEN '90%'
													WHEN '6. Firm (100%)'		THEN '100%'
													WHEN '7. Firm (100%)'		THEN '100%'
													WHEN '9. Lost (0%)'			THEN '0%'
													WHEN 'Working at Risk (100%)'THEN 'Working at Risk'
													ELSE 'Other'
												 END ,
					T.WonLostReason , 
					T.ClosePlanAccurate , 
					T.StandardRateCardUsed ,
					T.OrganicGrowth ,
					_crda_Hash			= CAST(NULL AS VARBINARY(16)) 
			INTO #Source 
			FROM	(
					SELECT	OpportunityId					= S.Id , 
							S.[Name] , 
							[Description]					= S.KimbleOne__Description__c ,
							S.AccountViewName__c ,
							SOReference						= S.SO_Reference__c , 
							LinkToProposal					= S.LinkToProposal__c , 
							ServiceProposition				= PP.[Name] , 
							TypeofWork						= S.TypeofWork__c , 
							CloseDate						= S.KimbleOne__CloseDate__c , 
							ResponseRequiredDate			= S.KimbleOne__CloseDate__c , 
							EarliestStartDate				= CONVERT(DATE, P.earliestStartDate__c, 120),
							LatestEndDate					= CONVERT(DATE, P.latestEndDate__c, 120),
							S._crda_ActiveFromDateTime , 
							S._crda_ActiveToDateTime , 
							ProposalActiveFrom				= CONVERT(DATETIME2(6), P._crda_ActiveFromDateTime), 
							WonLostReason					= S.KimbleOne__WonLostReason__c	, 
							ClosePlanAccurate				= NULL , 
							StandardRateCardUsed			= NULL , 
							OrganicGrowth					= NULL , 
							ProposalBk						= S.KimbleOne__Proposal__c , 
							ForecastStatusBk				= S.KimbleOne__ForecastStatus__c , 
							ForecastStatusName				= F.[Name] , 
							S.LastActivityDate , 
							S.LastModifiedDate 
					FROM		lh_SilverLayer.Kantata.HISTORY_SalesOpportunity	S 

					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	P	ON	P.Id	= S.KimbleOne__Proposal__c 
																			AND	P._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																			AND	P._crda_isDeleted = 0 

					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposition	PP	ON	PP.Id	= P.KimbleOne__Proposition__c 
																				AND	PP._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																				AND	PP._crda_isDeleted = 0 
					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= S.KimbleOne__ForecastStatus__c 
																				AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																				AND	F._crda_isDeleted = 0 

					WHERE	S._crda_isDeleted = 0 
					--AND		S.Id = '006Px00000L9oKtIAJ'

					UNION ALL 

					SELECT	O.Id , 
							O.[Name] , 
							O.[Description] ,
							A.AccountDisplayName__c , 
							SOReference						= O.KC_SO_Reference__c , 
							LinkToProposal					= O.KC_Link_To_Proposal__c , 
							ServiceProposition				= PP.[Name] , 
							TypeofWork						= O.[Type] , 
							O.CloseDate , 
							ResponseRequiredDate			= O.CloseDate , 
							EarliestStartDate				= CONVERT(DATE, P.earliestStartDate__c, 120),
							LatestEndDate					= CONVERT(DATE, P.latestEndDate__c, 120),
							O._crda_ActiveFromDateTime , 
							O._crda_ActiveToDateTime , 
							ProposalActiveFrom				= CONVERT(DATETIME2(6), P._crda_ActiveFromDateTime), 
							WonLostReason					= O.Reason_Lost__c , 
							ClosePlanAccurate				= O.Close_Plan_Accurate__c , 
							StandardRateCardUsed			= O.Standard_Rate_Card_Used__c , 
							OrganicGrowth					= O.Organic_Growth__c , 
							ProposalBk						= O.KimbleOne__Proposal__c , 
							ForecastStatusBk				= F.Id , 
							ForecastStatusName				= F.[Name] , 
							O.LastActivityDate , 
							O.LastModifiedDate 
					FROM		lh_SilverLayer.Kantata.HISTORY_Opportunity	O 
					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account		A	ON	A.Id	= O.AccountId 
																AND	A._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																AND	A._crda_isDeleted = 0 

					LEFT JOIN ( /*ForecastStatus.Name values changed Dec 2025*/
						SELECT	Id, [Name], _crda_ActiveToDateTime , 
								RN=ROW_NUMBER()OVER(
										PARTITION BY [Name] 
										ORDER BY _crda_ActiveToDateTime)
						FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus F 
						WHERE	F._crda_isDeleted = 0 
					)										FH	ON	FH.[Name] = O.StageName 
																AND	FH.RN = 1

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= FH.Id 
																				AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																				AND	F._crda_isDeleted = 0 

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Proposal	P	ON	P.Id	= O.KimbleOne__Proposal__c 
																			AND	P._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																			AND	P._crda_isDeleted = 0 

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Proposition	PP	ON	PP.Id	= P.KimbleOne__Proposition__c 
																				AND	PP._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																				AND	PP._crda_isDeleted = 0 

					WHERE	O._crda_isDeleted = 0 
					--AND		O.Id = '006Px00000L9oKtIAJ' 
		
					)											T 
			LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Proposal	KP	ON	KP.OpportunityId		 =  T.OpportunityId
																	AND	KP._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																	AND	KP._crda_isDeleted = 0 
			LEFT JOIN (
					SELECT	ProposalBk		= P.KimbleOne__Proposal__c , 
							IsNewBusiness	= MAX(IIF(P.KC_NewBusiness__c = 1, 1, 0)) 
					FROM	lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis P 
					WHERE	P._crda_isDeleted		= 0   
					AND		P._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
					AND		P.KimbleOne__AnalysisFact__c	
							IN	(	'a0E3z00000uZEf6EAG',	/*RevenueInternal*/
									'a0E3z00000uZEf7EAG',	/*CostInternal	 */
									'a0ED000000CxJIuMAN',	/*Revenue		 */
									'a0ED000000CxJIvMAN'	/*Cost			 */
								) 
					AND		P.KC_IsBalancingRecord__c = 0 
					GROUP BY P.KimbleOne__Proposal__c 
					)									PA	ON	PA.ProposalBk = KP.Id 

			WHERE	T._crda_ActiveFromDateTime > @_Watermark ; 


			UPDATE	R 
			SET		R._crda_Hash	= AD._crda_Hash 
			FROM	#Source	R 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  R.[Name]		
							, R.[Description] 	 
							, R.AccountViewName	
							, R.SOReference
							, R.LinkToProposal
							, R.ServiceProposition
							, R.TypeofWork 
							, R.CloseDate
							, R.ResponseRequiredDate
							, R.EarliestStartDate
							, R.LatestEndDate
							, R.IsNewBusiness 
							, R.DeliveryStatus
							, R.DeliverySplit
							, R.WonLostReason 
							, R.ClosePlanAccurate 
							, R.StandardRateCardUsed 
							, R.OrganicGrowth 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD ;


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'SalesOpportunity';


			INSERT INTO dbo.DimSalesOpportunity
			(
				SalesOpportunitySk , 
				SalesOpportunityBk , 
				[Name] , 
				[Description] , 
				AccountViewName , 
				SOReference , 
				LinkToProposal , 
				ServiceProposition , 
				TypeofWork , 
				CloseDate , 
				ResponseRequiredDate , 
				EarliestStartDate , 
				LatestEndDate , 
				IsNewBusiness , 
				DeliveryStatus , 
				DeliverySplit , 
				WonLostReason , 
				ClosePlanAccurate , 
				StandardRateCardUsed , 
				OrganicGrowth , 
				UrlToKanataRecord , 
				UrlToKanataDmwRecord 

				,_crda_ActiveFromDate 
				,_crda_ActiveToDate 
				,_crda_ActiveFromDateSk 
				,_crda_ActiveToDateSk 
				,IsCurrent 
				,_crda_Hash 
				,_crda_CreatedExecutionId  
				,_crda_CreatedDateTime 
				,_crda_isDeleted
			)
			SELECT 
				ROW_NUMBER()OVER (ORDER BY SRC.SalesOpportunityBk, SRC._crda_ActiveFromDateTime) ,
				SRC.SalesOpportunityBk , 
				SRC.[Name] , 
				SRC.[Description] , 
				SRC.AccountViewName , 
				SRC.SOReference , 
				SRC.LinkToProposal , 
				SRC.ServiceProposition , 
				SRC.TypeofWork , 
				SRC.CloseDate , 
				SRC.ResponseRequiredDate , 
				SRC.EarliestStartDate , 
				SRC.LatestEndDate , 
				SRC.IsNewBusiness , 
				SRC.DeliveryStatus , 
				SRC.DeliverySplit , 
				SRC.WonLostReason , 
				SRC.ClosePlanAccurate , 
				SRC.StandardRateCardUsed , 
				SRC.OrganicGrowth , 
				CONCAT('https://dmw.lightning.force.com/lightning/r/Opportunity/',SalesOpportunityBk) ,
				CONCAT('https://dmw--kimbleone.visualforce.com/apex/KimbleOne__SalesOppEdit?id=',SalesOpportunityBk) 


				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM		#Source	SRC 
			ORDER BY SRC.SalesOpportunityBk, SRC._crda_ActiveFromDateTime ; 


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Source S ;

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