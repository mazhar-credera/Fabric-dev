CREATE  
	PROCEDURE dbo.usp_Update_DimDeliveryElement
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryElement]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryElement]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryElement]')
	EXEC dbo.usp_Update_DimDeliveryElement @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT count(1) FROM dbo.DimDeliveryElement ;  --50632
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

			TRUNCATE TABLE dbo.DimDeliveryElement ; 

			INSERT INTO dbo.DimDeliveryElement ( 
				DeliveryElementSk, DeliveryElementBk, [Name], ShortName, CurrencyIsoCode , UrlToKanataPoRecord , 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT DeliveryElementSk, DeliveryElementBk, [Name], ShortName, CurrencyIsoCode , UrlToKanataPoRecord , 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord', 'UnknownRecord', 'ZZZ', '', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	DeliveryElementSk, DeliveryElementBk, [Name], ShortName, CurrencyIsoCode , UrlToKanataPoRecord , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimDeliveryElement B 
				WHERE	B.DeliveryElementSk = T.DeliveryElementSk 
			) ; 



			SELECT	DeliveryElementBk	= T.Id , 
					[Name]				= ISNULL(LEFT(T.[DisplayName__c] ,80) ,'') , 
					ShortName			= T.KimbleOne__ShortName__c ,
					CurrencyIsoCode		= T.CurrencyIsoCode ,

					StartDate			= T.KimbleOne__StartDate__c ,
					EndDate				= T.KimbleOne__EndDate__c ,

					EarliestAssignmentStartDate = T.KimbleOne__EarliestAssignmentStartDate__c ,
					LatestAssignmentEndDate		= T.KimbleOne__LatestAssignmentEndDate__c ,

					DeliveryGroupSk			= ISNULL(DG.DeliveryGroupSk , -1) ,
					ForecastStatusSk		= ISNULL(FS.ForecastStatusSk , -1) ,
					OriginatingProposalSk	= ISNULL(P1.ProposalSk , -1) ,
					ProductSk				= ISNULL(PD.ProductSk , -1) ,
					ProposalSk				= ISNULL(P.ProposalSk , -1) ,
					PracticeSk				= ISNULL(PC.PracticeSk , -1) ,

					Reference				= T.KimbleOne__Reference__c ,

					ContractMargin			= T.KimbleOne__ContractMargin__c ,
					ContractMarginAmount	= T.KimbleOne__ContractMarginAmount__c ,
					ContractRevenue			= T.KimbleOne__ContractRevenue__c ,
					WeightedContractRevenue = T.KimbleOne__WeightedContractRevenue__c ,

					LegalReview				= T.Legal_Review__c ,
					LegalReviewComments		= T.Legal_Review_Comments__c ,
					RiskReview				= T.Risk_Review__c ,
					WARApprovedUntil		= T.WARApprovedUntil__c , 
					TaxCodeBk				= T.KimbleOne__TaxCode__c , 
					ExcludeFromCashflowUntil= T.Exclude_From_Cashflow_Until__c , 
					UrlToKanataPoRecord		= CONCAT('https://dmw.lightning.force.com/lightning/r/KimbleOne__DeliveryElement__c/', T.Id, '/view') ,

					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	T 
			LEFT JOIN dbo.DimDeliveryGroup		DG	ON	DG.DeliveryGroupBk = T.KimbleOne__DeliveryGroup__c 
													--AND	T._crda_ActiveFromDateTime BETWEEN DG._crda_ActiveFromDate AND DG._crda_ActiveToDate
													AND	DG.IsCurrent = 1 
			LEFT JOIN dbo.DimForecastStatus		FS	ON	FS.ForecastStatusBk = T.KimbleOne__ForecastStatus__c  
													--AND	T._crda_ActiveFromDateTime BETWEEN FS._crda_ActiveFromDate AND FS._crda_ActiveToDate
													AND	FS.IsCurrent = 1 

			LEFT JOIN dbo.DimProposal			P	ON	P.ProposalBk = T.KimbleOne__Proposal__c  
													--AND	T._crda_ActiveFromDateTime BETWEEN P._crda_ActiveFromDate AND P._crda_ActiveToDate
													AND	P.IsCurrent = 1 

			LEFT JOIN dbo.DimProposal			P1	ON	P1.ProposalBk = T.KimbleOne__OriginatingProposal__c  
													--AND	T._crda_ActiveFromDateTime BETWEEN P1._crda_ActiveFromDate AND P1._crda_ActiveToDate
													AND	P1.IsCurrent = 1 

			LEFT JOIN dbo.DimProduct			PD	ON	PD.ProductBk = T.KimbleOne__Product__c  
													--AND	T._crda_ActiveFromDateTime BETWEEN PD._crda_ActiveFromDate AND PD._crda_ActiveToDate
													AND	PD.IsCurrent = 1 

			LEFT JOIN dbo.DimPractice			PC	ON	PC.PracticeBk = T.KC_Practice__c  
													--AND	T._crda_ActiveFromDateTime BETWEEN PC._crda_ActiveFromDate AND PC._crda_ActiveToDate
													AND	PC.IsCurrent = 1 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  LEFT(T.[DisplayName__c] ,80) 
							, T.KimbleOne__ShortName__c
							, T.CurrencyIsoCode

							, CONVERT(VARCHAR(50), T.KimbleOne__StartDate__c, 121)
							, CONVERT(VARCHAR(50), T.KimbleOne__EndDate__c, 121)

							, CONVERT(VARCHAR(50), T.KimbleOne__EarliestAssignmentStartDate__c, 121)
							, CONVERT(VARCHAR(50), T.KimbleOne__LatestAssignmentEndDate__c, 121)

							, ISNULL(DG.DeliveryGroupSk , -1)
							, ISNULL(FS.ForecastStatusSk , -1)
							, ISNULL(P1.ProposalSk , -1)
							, ISNULL(PD.ProductSk , -1)
							, ISNULL(P.ProposalSk , -1)
							, ISNULL(PC.PracticeSk , -1)

							, T.KimbleOne__Reference__c

							, T.KimbleOne__ContractMargin__c
							, T.KimbleOne__ContractMarginAmount__c
							, T.KimbleOne__ContractRevenue__c
							, T.KimbleOne__WeightedContractRevenue__c

							, T.Legal_Review__c
							, T.Legal_Review_Comments__c
							, T.Risk_Review__c
							, CONVERT(VARCHAR(50), T.WARApprovedUntil__c, 121) 
							, T.KimbleOne__TaxCode__c 
							, CONVERT(VARCHAR(50), T.Exclude_From_Cashflow_Until__c, 121) 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark 
			AND		T._crda_isDeleted = 0 ; 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'DeliveryElement';


			INSERT INTO dbo.DimDeliveryElement(
				  DeliveryElementSk 
				, DeliveryElementBk
				, [Name] 
				, ShortName
				, CurrencyIsoCode 
				, StartDate
				, EndDate
				, EarliestAssignmentStartDate
				, LatestAssignmentEndDate
				, DeliveryGroupSk
				, ForecastStatusSk
				, OriginatingProposalSk
				, PracticeSk
				, ProductSk
				, ProposalSk
				, Reference
				, ContractMargin
				, ContractMarginAmount
				, ContractRevenue
				, WeightedContractRevenue
				, LegalReview
				, LegalReviewComments
				, RiskReview
				, WARApprovedUntil
				, TaxCodeBk
				, ExcludeFromCashflowUntil
				,UrlToKanataPoRecord 

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
				  RN= ROW_NUMBER()OVER (PARTITION BY SRC.DeliveryElementBk ORDER BY SRC._crda_ActiveFromDateTime)
				, SRC.DeliveryElementBk
				, SRC.[Name] 
				, SRC.ShortName
				, SRC.CurrencyIsoCode
				, SRC.StartDate
				, SRC.EndDate
				, SRC.EarliestAssignmentStartDate
				, SRC.LatestAssignmentEndDate
				, SRC.DeliveryGroupSk
				, SRC.ForecastStatusSk
				, SRC.OriginatingProposalSk
				, SRC.PracticeSk
				, SRC.ProductSk
				, SRC.ProposalSk
				, SRC.Reference
				, SRC.ContractMargin
				, SRC.ContractMarginAmount
				, SRC.ContractRevenue
				, SRC.WeightedContractRevenue
				, SRC.LegalReview
				, SRC.LegalReviewComments
				, SRC.RiskReview
				, SRC.WARApprovedUntil
				, SRC.TaxCodeBk
				, SRC.ExcludeFromCashflowUntil 
				, SRC.UrlToKanataPoRecord 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM	#Source	SRC 
			ORDER BY
				SRC.DeliveryElementBk ,
				SRC._crda_ActiveFromDateTime ;


			/*Reassign lost FKs*/
			UPDATE	R 
			SET		DeliveryGroupSk = ISNULL(K1.DeliveryGroupSk , -1)
			--SELECT		R.DeliveryGroupSk , K1.DeliveryGroupSk , K.DeliveryGroupSk
			FROM	dbo.DimDeliveryElement			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	HR	ON	HR.Id						= R.DeliveryElementBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimDeliveryGroup		K	ON	K.DeliveryGroupSk = R.DeliveryGroupSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	RU	ON	RU.Id						= HR.KimbleOne__DeliveryGroup__c 
																			AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																			AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimDeliveryGroup	K1	ON	K1.DeliveryGroupBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.DeliveryGroupSk IS NULL ; 

			UPDATE	R 
			SET		ForecastStatusSk = ISNULL(K1.ForecastStatusSk  ,-1)
			FROM	dbo.DimDeliveryElement			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	HR	ON	HR.Id						= R.DeliveryElementBk
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
			SET		PracticeSk = ISNULL(K1.PracticeSk ,-1) 
			FROM	dbo.DimDeliveryElement			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	HR	ON	HR.Id						= R.DeliveryElementBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimPractice		K	ON	K.PracticeSk = R.PracticeSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Practice	RU	ON	RU.Id						= HR.KC_Practice__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimPractice	K1	ON	K1.PracticeBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.PracticeSk IS NULL ; 

			UPDATE	R 
			SET		ProposalSk = ISNULL(K1.ProposalSk  ,-1)
			--SELECT		R.ProposalSk , K1.ProposalSk , K.ProposalSk
			FROM	dbo.DimDeliveryElement			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	HR	ON	HR.Id						= R.DeliveryElementBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposal		K	ON	K.ProposalSk = R.ProposalSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	RU	ON	RU.Id						= HR.KimbleOne__Proposal__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposal	K1	ON	K1.ProposalBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.ProposalSk IS NULL ; 

			UPDATE	R 
			SET		OriginatingProposalSk = ISNULL(K1.ProposalSk ,-1)
			--SELECT		R.OriginatingProposalSk , K1.ProposalSk , K.ProposalSk
			FROM	dbo.DimDeliveryElement			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	HR	ON	HR.Id						= R.DeliveryElementBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposal		K	ON	K.ProposalSk = R.OriginatingProposalSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	RU	ON	RU.Id						= HR.KimbleOne__OriginatingProposal__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposal	K1	ON	K1.ProposalBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.ProposalSk IS NULL ; 


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