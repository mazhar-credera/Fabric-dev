CREATE   
	PROCEDURE dbo.usp_Update_DimProposal
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimProposal]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimProposal]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimProposal]')
	EXEC dbo.usp_Update_DimProposal @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	SELECT * FROM dbo.DimProposal ORDER BY ProposalSk;
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

			TRUNCATE TABLE dbo.DimProposal ; 

			INSERT INTO dbo.DimProposal ( 
				ProposalSk, ProposalBk, [Name], [Description] , ShortName , UrlToKantataRecord, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT ProposalSk, ProposalBk, [Name], [Description] , ShortName , UrlToKantataRecord, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' , '', '' , '', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	ProposalSk, ProposalBk, [Name], [Description] , ShortName , UrlToKantataRecord, 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimProposal B 
				WHERE	B.ProposalSk = T.ProposalSk 
			) ; 



			SELECT	ProposalBk					= T.Id , 
					[Name]						= ISNULL(LEFT(T.[DisplayName__c] ,80) , '') ,
					[Description]				= ISNULL(T.KimbleOne__Description__c , '') , 
					ShortName					= T.KimbleOne__ShortName__c , 
					T.CurrencyIsoCode , 
					AccountBk					= T.KimbleOne__Account__c , 
					AccountSk					= CAST(NULL AS INT),
					BusinessUnitBk				= T.KimbleOne__BusinessUnit__c , 
					BusinessUnitSk				= CAST(NULL AS INT),
					SalesOpportunityBk			= T.KimbleOne__SalesOpportunity__c , 
					SalesOpportunitySk			= CAST(NULL AS INT),
					ForecastStatusBk			= T.KimbleOne__ForecastStatus__c , 
					ForecastStatusSk			= CAST(NULL AS INT),
					PropositionBk				= T.KimbleOne__Proposition__c , 
					PropositionSk				= CAST(NULL AS INT),
					ContractCost				= T.KimbleOne__ContractCost__c ,
					ContractMargin				= T.KimbleOne__ContractMargin__c ,
					ContractMarginAmount		= T.KimbleOne__ContractMarginAmount__c ,
					ContractRevenue				= T.KimbleOne__ContractRevenue__c ,
					DetailedLevelContractCost	= T.KimbleOne__DetailedLevelContractCost__c ,
					DetailedLevelContractRevenue= T.KimbleOne__DetailedLevelContractRevenue__c ,
					DetailedLevelWeightedContractRevenue= T.KimbleOne__DetailedLevelWeightedContractRevenue__c ,
					Discount					= T.KimbleOne__Discount__c ,
					DiscountPercentage			= T.KimbleOne__DiscountPercentage__c ,
					HighLevelContractCost		= T.KimbleOne__HighLevelContractCost__c ,
					HighLevelContractRevenue	= T.KimbleOne__HighLevelContractRevenue__c ,
					HighLevelWeightedContractRevenue	= T.KimbleOne__HighLevelWeightedContractRevenue__c ,
					NumberOfItems				= T.KimbleOne__NumberOfItems__c ,
					ProposalCost				= T.KimbleOne__ProposalCost__c ,
					ProposalExpensesCost		= T.KimbleOne__ProposalExpensesCost__c ,
					ProposalMargin				= T.KimbleOne__ProposalMargin__c ,
					ProposalMarginAmount		= T.KimbleOne__ProposalMarginAmount__c ,
					ProposalUsageCost			= T.KimbleOne__ProposalUsageCost__c ,
					WeightedContractRevenue		= T.KimbleOne__WeightedContractRevenue__c ,
					DMWElementIsWAR				= T.DMW_Element_is_WAR__c ,
					ForecastAtDetailedLevel		= T.KimbleOne__ForecastAtDetailedLevel__c , 
					AcceptanceDate				= T.KimbleOne__AcceptanceDate__c , 
					DeliveryStartDate			= T.KimbleOne__DeliveryStartDate__c , 
					EarliestStartDate			= T.earliestStartDate__c , 
					LatestEndDate				= T.latestEndDate__c ,
					_crda_ActiveFromDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime		= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_Proposal		T 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  ISNULL(LEFT(T.[DisplayName__c] ,80) , '') 
								, T.[KimbleOne__Description__c]	 
								, T.KimbleOne__ShortName__c	
								, T.CurrencyIsoCode 
								, T.KimbleOne__Account__c 
								, T.KimbleOne__BusinessUnit__c 
								, T.KimbleOne__SalesOpportunity__c 

								, T.KimbleOne__ForecastStatus__c 
								, T.KimbleOne__Proposition__c 
								, T.KimbleOne__ContractCost__c
								, T.KimbleOne__ContractMargin__c
								, T.KimbleOne__ContractMarginAmount__c
								, T.KimbleOne__ContractRevenue__c
								, T.KimbleOne__DetailedLevelContractCost__c
								, T.KimbleOne__DetailedLevelContractRevenue__c
								, T.KimbleOne__DetailedLevelWeightedContractRevenue__c
								, T.KimbleOne__Discount__c
								, T.KimbleOne__DiscountPercentage__c
								, T.KimbleOne__HighLevelContractCost__c
								, T.KimbleOne__HighLevelContractRevenue__c
								, T.KimbleOne__HighLevelWeightedContractRevenue__c
								, T.KimbleOne__NumberOfItems__c
								, T.KimbleOne__ProposalCost__c
								, T.KimbleOne__ProposalExpensesCost__c
								, T.KimbleOne__ProposalMargin__c
								, T.KimbleOne__ProposalMarginAmount__c
								, T.KimbleOne__ProposalUsageCost__c
								, T.KimbleOne__WeightedContractRevenue__c
								, T.DMW_Element_is_WAR__c

								, T.KimbleOne__ForecastAtDetailedLevel__c 
								, CONVERT(VARCHAR(35), T.KimbleOne__AcceptanceDate__c , 121) 
								, CONVERT(VARCHAR(35), T.KimbleOne__DeliveryStartDate__c , 121) 
								, CONVERT(VARCHAR(35), T.earliestStartDate__c , 121) 
								, CONVERT(VARCHAR(35), T.latestEndDate__c , 121)
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Proposal' ;
--SELECT * FROM #Source 

			/*Update AccountSk*/ 
			UPDATE	S 
			SET		S.AccountSk	= ISNULL(A.AccountSk, -1) 
			FROM	#Source			 S
			LEFT JOIN dbo.DimAccount A	ON	A.AccountBk = S.AccountBk 
										AND	S._crda_ActiveFromDateTime BETWEEN A._crda_ActiveFromDate AND A._crda_ActiveToDate
										--AND	A.IsCurrent = 1 ;

			/*Update BusinessUnitSk*/
			UPDATE	S 
			SET		S.BusinessUnitSk	= ISNULL(B.BusinessUnitSk, -1) 
			FROM	#Source					S
			LEFT JOIN dbo.DimBusinessUnit	B	ON	B.BusinessUnitBk = S.BusinessUnitBk 
												AND	S._crda_ActiveFromDateTime BETWEEN B._crda_ActiveFromDate AND B._crda_ActiveToDate
												--AND	B.IsCurrent = 1 ;

			/*Update SalesOpportunitySk*/
			UPDATE	S 
			SET		S.SalesOpportunitySk	= ISNULL(SO.SalesOpportunitySk, -1) 
			FROM	#Source						S
			LEFT JOIN dbo.DimSalesOpportunity	SO	ON	SO.SalesOpportunityBk = S.SalesOpportunityBk 
													AND	S._crda_ActiveFromDateTime BETWEEN SO._crda_ActiveFromDate AND SO._crda_ActiveToDate
													--AND	SO.IsCurrent = 1 ;

			/*Update ForecastStatusSk*/
			UPDATE	S 
			SET		S.ForecastStatusSk	= ISNULL(F.ForecastStatusSk, -1) 
			FROM	#Source						S
			LEFT JOIN dbo.DimForecastStatus		F	ON	F.ForecastStatusBk = S.ForecastStatusBk 
													AND	S._crda_ActiveFromDateTime BETWEEN F._crda_ActiveFromDate AND F._crda_ActiveToDate 
													--AND	F.IsCurrent = 1 ;

			/*Update PropositionSk*/
			UPDATE	S 
			SET		S.PropositionSk	= ISNULL(P.PropositionSk, -1) 
			FROM	#Source					S
			LEFT JOIN dbo.DimProposition	P	ON	P.PropositionBk = S.PropositionBk 
												AND	S._crda_ActiveFromDateTime BETWEEN P._crda_ActiveFromDate AND P._crda_ActiveToDate 
												--AND	P.IsCurrent = 1 ;



			INSERT INTO dbo.DimProposal(
				ProposalSk , 
				ProposalBk , 
				[Name] , 
				[Description] , 
				ShortName , 
				CurrencyIsoCode , 
				AccountSk , 	
				BusinessUnitSk , 
				SalesOpportunitySk , 
				ForecastStatusSk , 
				PropositionSk , 
				ContractCost , 
				ContractMargin , 
				ContractMarginAmount , 
				ContractRevenue , 
				DetailedLevelContractCost , 
				DetailedLevelContractRevenue , 
				DetailedLevelWeightedContractRevenue , 
				Discount , 
				DiscountPercentage , 
				HighLevelContractCost , 
				HighLevelContractRevenue , 
				HighLevelWeightedContractRevenue , 
				NumberOfItems , 
				ProposalCost , 
				ProposalExpensesCost , 
				ProposalMargin , 
				ProposalMarginAmount , 
				ProposalUsageCost , 
				WeightedContractRevenue , 
				DMWElementIsWAR , 
				ForecastAtDetailedLevel ,
				AcceptanceDate , 
				DeliveryStartDate , 
				EarliestStartDate ,
				LatestEndDate , 
				UrlToKantataRecord 

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
				ROW_NUMBER()OVER (ORDER BY SRC.ProposalBk, SRC._crda_ActiveFromDateTime) , 
				SRC.ProposalBk , 
				SRC.[Name] , 
				SRC.[Description] , 
				SRC.ShortName , 
				SRC.CurrencyIsoCode , 
				SRC.AccountSk , 	
				SRC.BusinessUnitSk , 
				SRC.SalesOpportunitySk , 
				SRC.ForecastStatusSk , 
				SRC.PropositionSk , 
				CAST(SRC.ContractCost AS DECIMAL(18,2) ) , 
				CAST(SRC.ContractMargin AS DECIMAL(18,2) ) , 
				CAST(SRC.ContractMarginAmount AS DECIMAL(18,2) ) , 
				CAST(SRC.ContractRevenue AS DECIMAL(18,2) ) , 
				CAST(SRC.DetailedLevelContractCost AS DECIMAL(18,2) ) , 
				CAST(SRC.DetailedLevelContractRevenue AS DECIMAL(18,2) ) , 
				CAST(SRC.DetailedLevelWeightedContractRevenue AS DECIMAL(18,2) ) , 
				CAST(SRC.Discount AS DECIMAL(18,2) ) , 
				CAST(SRC.DiscountPercentage AS DECIMAL(18,2) ) , 
				CAST(SRC.HighLevelContractCost AS DECIMAL(18,2) ) , 
				CAST(SRC.HighLevelContractRevenue AS DECIMAL(18,2) ) , 
				CAST(SRC.HighLevelWeightedContractRevenue AS DECIMAL(18,2) ) , 
				CAST(SRC.NumberOfItems	AS DECIMAL(18,2) ) , 
				CAST(SRC.ProposalCost	AS DECIMAL(18,2) ) , 
				CAST(SRC.ProposalExpensesCost  AS DECIMAL(18,2) ) , 
				CAST(SRC.ProposalMargin  AS DECIMAL(18,2) ) , 
				CAST(SRC.ProposalMarginAmount AS DECIMAL(18,2) ) , 
				CAST(SRC.ProposalUsageCost AS DECIMAL(18,2) ) , 
				CAST(SRC.WeightedContractRevenue AS DECIMAL(18,2) ) , 
				SRC.DMWElementIsWAR , 
				SRC.ForecastAtDetailedLevel ,
				SRC.AcceptanceDate , 
				SRC.DeliveryStartDate , 
				SRC.EarliestStartDate ,
				SRC.LatestEndDate , 
				CONCAT('https://dmw.lightning.force.com/lightning/r/KimbleOne__Proposal__c/',ProposalBk, '/view') 

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
			ORDER BY SRC.ProposalBk, SRC._crda_ActiveFromDateTime ; 


			/*Reassign lost FKs*/
			UPDATE	R 
			SET		BusinessUnitSk	= ISNULL(K1.BusinessUnitSk , -1)
			--SELECT		R.BusinessUnitSk , K1.BusinessUnitSk , K.BusinessUnitSk
			FROM	dbo.DimProposal			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	HR	ON	HR.Id						= R.ProposalBk
													AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimBusinessUnit		K	ON	K.BusinessUnitSk = R.BusinessUnitSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_BusinessUnit	RU	ON	RU.Id						= HR.KimbleOne__BusinessUnit__c 
															AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
															AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimBusinessUnit	K1	ON	K1.BusinessUnitBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.BusinessUnitSk IS NULL ; 

			UPDATE	R 
			SET		AccountSk		= ISNULL(K1.AccountSk , -1)
			--SELECT		R.AccountSk , K1.AccountSk , K.AccountSk
			FROM	dbo.DimProposal			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	HR	ON	HR.Id						= R.ProposalBk
													AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount		K	ON	K.AccountSk = R.AccountSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account	RU	ON	RU.Id						= HR.KimbleOne__Account__c 
															AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
															AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount	K1	ON	K1.AccountBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.AccountSk IS NULL ; 

			UPDATE	R 
			SET		ForecastStatusSk = ISNULL(K1.ForecastStatusSk , -1)
			--SELECT		R.ForecastStatusSk , K1.ForecastStatusSk , K.ForecastStatusSk
			FROM	dbo.DimProposal			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	HR	ON	HR.Id						= R.ProposalBk
													AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimForecastStatus		K	ON	K.ForecastStatusSk = R.ForecastStatusSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	RU	ON	RU.Id						= HR.KimbleOne__ForecastStatus__c 
															AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
															AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimForecastStatus	K1	ON	K1.ForecastStatusBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.ForecastStatusSk IS NULL ; 

			UPDATE	R	
			SET		PropositionSk = ISNULL(K1.PropositionSk , -1)
			--SELECT		R.PropositionSk , K1.PropositionSk , K.PropositionSk
			FROM	dbo.DimProposal			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	HR	ON	HR.Id						= R.ProposalBk
													AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposition		K	ON	K.PropositionSk = R.PropositionSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposition	RU	ON	RU.Id						= HR.KimbleOne__Proposition__c 
															AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
															AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposition	K1	ON	K1.PropositionBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.PropositionSk IS NULL ; 


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