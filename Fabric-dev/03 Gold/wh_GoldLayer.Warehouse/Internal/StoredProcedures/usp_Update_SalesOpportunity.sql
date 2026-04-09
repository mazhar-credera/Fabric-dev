CREATE  
	PROCEDURE Internal.usp_Update_SalesOpportunity
	--Default Parameters 
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 

AS 
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	PA - > Proposal -> SalesOp/Opp.

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_SalesOpportunity]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_SalesOpportunity]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_SalesOpportunity]')
	EXEC Internal.usp_Update_SalesOpportunity @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId
	SELECT COUNT(1) FROM Internal.SalesOpportunity ; 
	--TRUNCATE TABLE Internal.SalesOpportunity ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2),
			@_ProcessId		INT		= @ProcessId, 
			@TimeNow		DATETIME2= GETUTCDATE() ;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			WITH cteSalesOpps
			AS(
					SELECT	OpportunityBk					= S.Id , 
							S.CreatedDate , 
							ForecastStatusBk				= S.KimbleOne__ForecastStatus__c , 
							OpportunitySourceBk				= S.KimbleOne__OpportunitySource__c , 
							Sector							= S.Sector__c 
					FROM		lh_SilverLayer.Kantata.HISTORY_SalesOpportunity	S 

					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	P	ON	P.Id	= S.KimbleOne__Proposal__c 
																				AND	P._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																				AND	P._crda_isDeleted		 = 0 

					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposition	PP	ON	PP.Id	= P.KimbleOne__Proposition__c 
																				AND	PP._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																				AND	PP._crda_isDeleted		 = 0 

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= S.KimbleOne__ForecastStatus__c 
																					AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																					AND	F._crda_isDeleted		= 0 

					WHERE	S._crda_isDeleted		 = 0 
					AND		S._crda_ActiveToDateTime= '9999-12-31 23:59:59'
					--AND		S.Id = '006Px00000L9oKtIAJ'

					UNION ALL 

					SELECT	OpportunityBk					= O.Id , 
							O.CreatedDate , 
							ForecastStatusBk				= F.Id , 
							OpportunitySourceBk				= CAST(NULL AS VARCHAR(18)) , 
							Sector							= O.KC_Sector__c 
					FROM		lh_SilverLayer.Kantata.HISTORY_Opportunity	O 

					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account		A	ON	A.Id	= O.AccountId 
																				AND	A._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																				AND	A._crda_isDeleted		 = 0 

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
																				AND	F._crda_isDeleted		 = 0 

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Proposal	P	ON	P.Id	= O.KimbleOne__Proposal__c 
																			AND	P._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																			AND	P._crda_isDeleted		 = 0 

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Proposition	PP	ON	PP.Id	= P.KimbleOne__Proposition__c 
																				AND	PP._crda_ActiveToDateTime= '9999-12-31 23:59:59'
																				AND	PP._crda_isDeleted		 = 0 

					WHERE	O._crda_isDeleted		 = 0 
					AND		O._crda_ActiveToDateTime= '9999-12-31 23:59:59'
					--AND		O.Id = '006Px00000L9oKtIAJ' 
			)
			SELECT  
				 SalesOpportunityBk		= SO.OpportunityBk 
				,SalesOpsCreatedDateTime= SO.CreatedDate 
				,PerformanceAnalysisBk	= PA.Id 
				,AccountBk				= PA.KimbleOne__Account__c 
				,ProposalBk				= PA.KimbleOne__Proposal__c 
				,SalesOpForecastStatusBk= SO.ForecastStatusBk 
				,PaForecastStatusBk		= FS.Id 
				,OpportunitySourceBk	= SO.OpportunitySourceBk 
				,SectorBk				= SC.Id 
				,AnalysisFactBk			= AF.Id 
				,PaBusinessUnitBk		= PA.KimbleOne__BusinessUnit__c  

				,TotalRevenue			= COALESCE(PA.KimbleOne__ActualRevenue__c
													+ PA.WeightedP1OnlyExcActual__c 
														+ PA.WeightedP2Only__c 
															+ PA.WeightedP3Only__c , 0)

				,WeightedRevenue		= COALESCE(	
											CASE FSS.[Name]
												WHEN '1. Lead (1%)'			THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3
												WHEN '2. Qualify (10%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3		
												WHEN '3. Solutions (25%)'	THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3
												WHEN '4. Propose (50%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3
												WHEN '5. Negotiate (75%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc * (FSS.KimbleOne__Probability__c * 0.01)		--P2
												WHEN '6. Verbal Win (90%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P2
												WHEN '7. Firm (100%)'		THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1
												WHEN 'Working at Risk (100%)'THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1												
												ELSE 0
											END , 0)
				,UnweightedRevenue		= COALESCE(	
												CASE FSS.[Name]
													WHEN '1. Lead (1%)'			THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
													WHEN '2. Qualify (10%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
													WHEN '3. Solutions (25%)'	THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
													WHEN '4. Propose (50%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
													WHEN '5. Negotiate (75%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	--P2
													WHEN '6. Verbal Win (90%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	--P2
													WHEN '7. Firm (100%)'		THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1
													WHEN 'Working at Risk (100%)'THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1
													ELSE 0 
											END , 0)
				,PA._crda_ActiveFromDateTime 

			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_PerformanceAnalysis    PA     

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_AnalysisFact		AF	ON  AF.Id						= PA.KimbleOne__AnalysisFact__c 
																			AND	AF._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
																			AND	AF._crda_isDeleted			= 0 
																							/*'Revenue'			'Cost'					RevenueInternal			CostInternal*/
																			AND AF.Id IN ('a0ED000000CxJIuMAN', 'a0ED000000CxJIvMAN', 'a0E3z00000uZEf6EAG', 'a0E3z00000uZEf7EAG')	

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal			PR	ON	PR.Id						= PA.KimbleOne__Proposal__c 
																			AND	PR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
																			AND	PR._crda_isDeleted			= 0 

			INNER JOIN	cteSalesOpps									SO	ON	SO.OpportunityBk			= PR.OpportunityId 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Sector			SC	ON	SC.[Name]					= SO.Sector
																			AND	SC._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
																			AND	SC._crda_isDeleted			= 0 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	FS	ON	FS.[Name]					= PA.DeliveryElementStatus__c 
																			AND	FS._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
																			AND	FS._crda_isDeleted			= 0 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	FSS	ON	FSS.Id						= SO.ForecastStatusBk  
																			AND	FSS._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
																			AND	FSS._crda_isDeleted			= 0 

			WHERE	PA._crda_isDeleted = 0 
			AND		PA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			AND		PA._crda_ActiveFromDateTime >= @_Watermark ; 



			TRUNCATE TABLE Internal.SalesOpportunity ; 

			INSERT INTO	Internal.SalesOpportunity 
			( 
				SalesOpportunityBk , 
				SalesOpsCreatedDateTime , 
				PerformanceAnalysisBk , 
				AccountBk , 
				ProposalBk ,
				SalesOpForecastStatusBk , 
				PaForecastStatusBk	, 
				OpportunitySourceBk ,
				SectorBk ,
				AnalysisFactBk , 
				PaBusinessUnitBk , 

				TotalRevenue ,
				WeightedRevenue ,
				UnweightedRevenue ,

				_crda_ValidFromDateTime , 

				_crda_CreatedExecutionId , 
				_crda_CreatedDateTime 
			)
			SELECT 
				SRC.SalesOpportunityBk , 
				SRC.SalesOpsCreatedDateTime , 
				SRC.PerformanceAnalysisBk , 
				SRC.AccountBk , 
				SRC.ProposalBk ,
				SRC.SalesOpForecastStatusBk , 
				SRC.PaForecastStatusBk	, 
				SRC.OpportunitySourceBk ,
				SRC.SectorBk ,
				SRC.AnalysisFactBk , 
				SRC.PaBusinessUnitBk , 

				SRC.TotalRevenue ,
				SRC.WeightedRevenue ,
				SRC.UnweightedRevenue ,

				SRC._crda_ValidFromDateTime , 
				@_ExecutionId , 
				GETUTCDATE() 

			FROM	#Source 
			ORDER BY 
				 SalesOpportunityBk 
				,SalesOpsCreatedDateTime 
				,PerformanceAnalysisBk ; 

			/*PK/Unique constraints are not enforced so...*/
			;WITH cteDups
			AS( 
				SELECT	 SalesOpportunityBk, SalesOpsCreatedDateTime, PerformanceAnalysisBk 
						,RN =	ROW_NUMBER() 
								OVER (
									PARTITION BY	SalesOpportunityBk, SalesOpsCreatedDateTime, PerformanceAnalysisBk 
									ORDER BY		SalesOpportunityBk, SalesOpsCreatedDateTime 
								)
				FROM	Internal.SalesOpportunity T
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