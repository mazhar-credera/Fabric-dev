CREATE  
	PROCEDURE dbo.usp_Update_DimDeliveryGroup
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryGroup]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryGroup]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryGroup]')
	EXEC dbo.usp_Update_DimDeliveryGroup @ExecutionId = @LastExecId, @Watermark ='2025-06-01', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimDeliveryGroup ; --55301
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

			TRUNCATE TABLE dbo.DimDeliveryGroup ; 

			INSERT INTO dbo.DimDeliveryGroup ( 
				DeliveryGroupSk, DeliveryGroupBk, [Name], CurrencyIsoCode, UrlToKanataRevenuesAndCostsRecord, UrlToKanataRecord, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT DeliveryGroupSk, DeliveryGroupBk, [Name], CurrencyIsoCode, UrlToKanataRevenuesAndCostsRecord, UrlToKanataRecord, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' , 'ZZZ', '', '', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	DeliveryGroupSk, DeliveryGroupBk, [Name], CurrencyIsoCode, UrlToKanataRevenuesAndCostsRecord, UrlToKanataRecord, 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimDeliveryGroup B 
				WHERE	B.DeliveryGroupSk = T.DeliveryGroupSk 
			) ; 



			SELECT 
				DeliveryGroupBk			= T.Id , 
				[Name]					= LEFT(ISNULL(T.[DisplayName__c], '') , 255) , 
				ShortName				= T.KimbleOne__ShortName__c , 
				CurrencyIsoCode			= T.CurrencyIsoCode ,

				ExpectedStartDate		= T.KimbleOne__ExpectedStartDate__c ,
				ExpectedEndDate			= T.KimbleOne__ExpectedEndDate__c ,

				AccountSk				= ISNULL(AC.AccountSk , -1) ,
				BillingAccountSk		= ISNULL(AB.AccountSk , -1) ,
				ForecastStatusSk		= ISNULL(FS.ForecastStatusSk , -1) ,
				ProposalSk				= ISNULL(PS.ProposalSk , -1) ,

				DeliveryProgram			= ISNULL(DP.[Name] , '') , 
				DeliveryStage			= ISNULL(DS.[Name] , '') , 
				DeliveryStatus			= ISNULL(DST.[Name] , '') , 

				LostReason				= T.KimbleOne__LostReason__c ,
				LostReasonNarrative		= T.KimbleOne__LostReasonNarrative__c ,
				ProbabilityCodeEnum		= T.KimbleOne__ProbabilityCodeEnum__c ,

				ExternalEngagementReference			= T.ExternalEngagementReference__c ,
				ForecastAtThisLevel					= T.KimbleOne__ForecastAtThisLevel__c ,
				Reference							= T.KimbleOne__Reference__c ,
				RiskLevel							= T.KimbleOne__RiskLevel__c ,

				ActualUsage							= T.KimbleOne__ActualUsage__c ,
				BaselineContractCost				= T.KimbleOne__BaselineContractCost__c ,
				BaselineContractMargin				= T.KimbleOne__BaselineContractMargin__c ,
				BaselineContractMarginAmount		= T.KimbleOne__BaselineContractMarginAmount__c ,
				BaselineContractRevenue				= T.KimbleOne__BaselineContractRevenue__c ,
				BaselineExpensesContractCost		= T.KimbleOne__BaselineExpensesContractCost__c ,
				BaselineExpensesContractMargin		= T.KimbleOne__BaselineExpensesContractMargin__c ,
				BaselineExpensesContractMarginAmount= T.KimbleOne__BaselineExpensesContractMarginAmount__c ,
				BaselineExpensesContractRevenue		= T.KimbleOne__BaselineExpensesContractRevenue__c ,
				BaselineServicesContractCost		= T.KimbleOne__BaselineServicesContractCost__c ,
				BaselineServicesContractMargin		= T.KimbleOne__BaselineServicesContractMargin__c ,
				BaselineServicesContractMarginAmount= T.KimbleOne__BaselineServicesContractMarginAmount__c ,
				BaselineServicesContractRevenue		= T.KimbleOne__BaselineServicesContractRevenue__c ,
				BaselineUsage						= T.KimbleOne__BaselineUsage__c ,

				ContractCost						= T.KimbleOne__ContractCost__c ,
				ContractMargin						= T.KimbleOne__ContractMargin__c ,
				ContractMarginAmount				= T.KimbleOne__ContractMarginAmount__c ,
				ContractRevenue						= T.KimbleOne__ContractRevenue__c ,

				ExpensesContractCost				= T.KimbleOne__ExpensesContractCost__c ,
				ExpensesContractMargin				= T.KimbleOne__ExpensesContractMargin__c ,
				ExpensesContractMarginAmount		= T.KimbleOne__ExpensesContractMarginAmount__c ,
				ExpensesContractRevenue				= T.KimbleOne__ExpensesContractRevenue__c ,
				ExpensesSupplierInvoiceableAmount	= T.KimbleOne__ExpensesSupplierInvoiceableAmount__c ,
				ForecastUsage						= T.KimbleOne__ForecastUsage__c ,

				InvoicingCcyExpensesInvoiceableAmount	= T.KimbleOne__InvoicingCcyExpensesInvoiceableAmount__c ,
				InvoicingCcyServicesInvoiceableAmount	= T.KimbleOne__InvoicingCcyServicesInvoiceableAmount__c ,
				InvoicingCurrencyContractRevenue		= T.KimbleOne__InvoicingCurrencyContractRevenue__c ,
				InvoicingCurrencyIsoCode				= T.KimbleOne__InvoicingCurrencyIsoCode__c ,

				KC_IsActive								= T.KC_IsActive__c ,
				KC_IsWon								= T.KC_IsWon__c ,
				KC_Trigger								= T.KC_Trigger__c ,

				ProposalItemsCostTotal					= T.KimbleOne__ProposalItemsCostTotal__c ,
				ProposalItemsMargin						= T.KimbleOne__ProposalItemsMargin__c ,
				ProposalItemsMarginAmount				= T.KimbleOne__ProposalItemsMarginAmount__c ,
				ServicesContractCost					= T.KimbleOne__ServicesContractCost__c ,
				ServicesContractMargin					= T.KimbleOne__ServicesContractMargin__c ,
				ServicesContractMarginAmount			= T.KimbleOne__ServicesContractMarginAmount__c ,
				ServicesContractRevenue					= T.KimbleOne__ServicesContractRevenue__c ,
				ServicesSupplierInvoiceableAmount		= T.KimbleOne__ServicesSupplierInvoiceableAmount__c ,

				SharedWithCustomer						= T.KimbleOne__SharedWithCustomer__c ,
				WeightedContractRevenue					= T.KimbleOne__WeightedContractRevenue__c ,
				WhatIfDifference						= T.KimbleOne__WhatIfDifference__c ,
				UrlToKanataRevenuesAndCostsRecord		= CONCAT('https://dmw.lightning.force.com/lightning/r/KimbleOne__DeliveryGroup__c/', T.Id, '/view') ,
				UrlToKanataRecord						= CONCAT('https://dmw.lightning.force.com/lightning/r/KimbleOne__DeliveryGroup__c/', T.Id, '/view') ,

				T._crda_ActiveFromDateTime , 
				T._crda_ActiveToDateTime , 
				AD._crda_Hash 
			INTO	#Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	T 
			LEFT JOIN	dbo.DimAccount				AC	ON	AC.AccountBk	= T.KimbleOne__Account__c 
														--AND	T._crda_ActiveFromDateTime BETWEEN AC._crda_ActiveFromDate AND AC._crda_ActiveToDate
														AND	AC.IsCurrent	= 1
			LEFT JOIN	dbo.DimAccount				AB	ON	AB.AccountBk	= T.KimbleOne__BillingAccount__c  
														--AND	T._crda_ActiveFromDateTime BETWEEN AB._crda_ActiveFromDate AND AB._crda_ActiveToDate
														AND	AB.IsCurrent	= 1 
			LEFT JOIN	dbo.DimForecastStatus		FS	ON	FS.ForecastStatusBk = T.KimbleOne__ForecastStatus__c 
														--AND	T._crda_ActiveFromDateTime BETWEEN FS._crda_ActiveFromDate AND FS._crda_ActiveToDate
														AND	FS.IsCurrent		= 1 
			LEFT JOIN	dbo.DimProposal				PS	ON	PS.ProposalBk	= T.KimbleOne__Proposal__c 
														--AND	T._crda_ActiveFromDateTime BETWEEN PS._crda_ActiveFromDate AND PS._crda_ActiveToDate
														AND	PS.IsCurrent	= 1

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryProgram	DP	ON	DP.Id	= T.KimbleOne__DeliveryProgram__c  
																			AND DP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																			AND	DP._crda_isDeleted = 0 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryStage	DS	ON	DS.Id	= T.KimbleOne__DeliveryStage__c  
																			AND DS._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																			AND	DS._crda_isDeleted = 0 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryStatus	DST	ON	DST.Id	= T.KimbleOne__DeliveryStatus__c  
																			AND DST._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																			AND	DST._crda_isDeleted = 0 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  LEFT(ISNULL(T.[DisplayName__c], '') , 255) 
							, T.KimbleOne__ShortName__c
							, T.CurrencyIsoCode

							, CONVERT(VARCHAR(50), T.KimbleOne__ExpectedStartDate__c, 121)
							, CONVERT(VARCHAR(50), T.KimbleOne__ExpectedEndDate__c, 121)

							, ISNULL(AC.AccountSk , -1) 
							, ISNULL(FS.ForecastStatusSk , -1)
							, ISNULL(PS.ProposalSk , -1)
						
							, ISNULL(DP.[Name] , '') 
							, ISNULL(DS.[Name] , '') 
							, ISNULL(DST.[Name] , '') 

							, T.KimbleOne__LostReason__c
							, T.KimbleOne__LostReasonNarrative__c
							, T.KimbleOne__ProbabilityCodeEnum__c

							, T.ExternalEngagementReference__c
							, T.KimbleOne__ForecastAtThisLevel__c
							, T.KimbleOne__Reference__c
							, T.KimbleOne__RiskLevel__c

							, T.KimbleOne__ActualUsage__c
							, T.KimbleOne__BaselineContractCost__c
							, T.KimbleOne__BaselineContractMargin__c
							, T.KimbleOne__BaselineContractMarginAmount__c
							, T.KimbleOne__BaselineContractRevenue__c
							, T.KimbleOne__BaselineExpensesContractCost__c
							, T.KimbleOne__BaselineExpensesContractMargin__c
							, T.KimbleOne__BaselineExpensesContractMarginAmount__c
							, T.KimbleOne__BaselineExpensesContractRevenue__c
							, T.KimbleOne__BaselineServicesContractCost__c
							, T.KimbleOne__BaselineServicesContractMargin__c
							, T.KimbleOne__BaselineServicesContractMarginAmount__c
							, T.KimbleOne__BaselineServicesContractRevenue__c
							, T.KimbleOne__BaselineUsage__c
							, T.KimbleOne__BillingAccount__c
							, T.KimbleOne__BillingContact__c

							, T.KimbleOne__ContractCost__c
							, T.KimbleOne__ContractMargin__c
							, T.KimbleOne__ContractMarginAmount__c
							, T.KimbleOne__ContractRevenue__c

							, T.KimbleOne__ExpensesContractCost__c
							, T.KimbleOne__ExpensesContractMargin__c
							, T.KimbleOne__ExpensesContractMarginAmount__c
							, T.KimbleOne__ExpensesContractRevenue__c
							, T.KimbleOne__ExpensesSupplierInvoiceableAmount__c
							, T.KimbleOne__ForecastUsage__c

							, T.KimbleOne__InvoicingCcyExpensesInvoiceableAmount__c
							, T.KimbleOne__InvoicingCcyServicesInvoiceableAmount__c
							, T.KimbleOne__InvoicingCurrencyContractRevenue__c
							, T.KimbleOne__InvoicingCurrencyIsoCode__c

							, T.KC_IsActive__c
							, T.KC_IsWon__c
							, T.KC_Trigger__c

							, T.KimbleOne__ProposalItemsCostTotal__c
							, T.KimbleOne__ProposalItemsMargin__c
							, T.KimbleOne__ProposalItemsMarginAmount__c

							, T.KimbleOne__ServicesContractCost__c
							, T.KimbleOne__ServicesContractMargin__c
							, T.KimbleOne__ServicesContractMarginAmount__c
							, T.KimbleOne__ServicesContractRevenue__c
							, T.KimbleOne__ServicesSupplierInvoiceableAmount__c

							, T.KimbleOne__SharedWithCustomer__c
							, T.KimbleOne__WeightedContractRevenue__c
							, T.KimbleOne__WhatIfDifference__c			
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark 
			AND		T._crda_isDeleted = 0 ;


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'DeliveryGroup';


			INSERT INTO dbo.DimDeliveryGroup(
				  DeliveryGroupSk 
				, DeliveryGroupBk 
 				, [Name]
				, ShortName
				, CurrencyIsoCode

				, ExpectedStartDate
				, ExpectedEndDate

				, AccountSk
				, BillingAccountSk
				, ForecastStatusSk
				, ProposalSk

				, DeliveryProgram
				, DeliveryStage
				, DeliveryStatus

				, LostReason
				, LostReasonNarrative
				, ProbabilityCodeEnum

				, ExternalEngagementReference
				, ForecastAtThisLevel
				, Reference
				, RiskLevel

				, ActualUsage
				, BaselineContractCost
				, BaselineContractMargin
				, BaselineContractMarginAmount
				, BaselineContractRevenue
				, BaselineExpensesContractCost
				, BaselineExpensesContractMargin
				, BaselineExpensesContractMarginAmount
				, BaselineExpensesContractRevenue
				, BaselineServicesContractCost
				, BaselineServicesContractMargin
				, BaselineServicesContractMarginAmount
				, BaselineServicesContractRevenue
				, BaselineUsage

				, ContractCost
				, ContractMargin
				, ContractMarginAmount
				, ContractRevenue
				, ExpensesContractCost
				, ExpensesContractMargin
				, ExpensesContractMarginAmount
				, ExpensesContractRevenue
				, ExpensesSupplierInvoiceableAmount
				, ForecastUsage
				, InvoicingCcyExpensesInvoiceableAmount
				, InvoicingCcyServicesInvoiceableAmount
				, InvoicingCurrencyContractRevenue
				, InvoicingCurrencyIsoCode

				, KC_IsActive
				, KC_IsWon
				, KC_Trigger

				, ProposalItemsCostTotal
				, ProposalItemsMargin
				, ProposalItemsMarginAmount
				, ServicesContractCost
				, ServicesContractMargin
				, ServicesContractMarginAmount
				, ServicesContractRevenue
				, ServicesSupplierInvoiceableAmount
				, WeightedContractRevenue
				, WhatIfDifference

				, SharedWithCustomer
				, UrlToKanataRevenuesAndCostsRecord
				, UrlToKanataRecord	

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
				  RN= ROW_NUMBER()OVER (PARTITION BY SRC.DeliveryGroupBk ORDER BY SRC._crda_ActiveFromDateTime)
				, SRC.DeliveryGroupBk 
				, LEFT(SRC.[Name], 80) 
				, SRC.ShortName
				, SRC.CurrencyIsoCode

				, SRC.ExpectedStartDate
				, SRC.ExpectedEndDate

				, SRC.AccountSk
				, SRC.BillingAccountSk
				, SRC.ForecastStatusSk
				, SRC.ProposalSk

				, SRC.DeliveryProgram
				, SRC.DeliveryStage
				, SRC.DeliveryStatus

				, LEFT(SRC.LostReason, 50)
				, LEFT(SRC.LostReasonNarrative, 255)
				, LEFT(SRC.ProbabilityCodeEnum, 50)

				, LEFT(SRC.ExternalEngagementReference, 255)
				, LEFT(SRC.ForecastAtThisLevel, 10)
				, LEFT(SRC.Reference, 100)
				, LEFT(SRC.RiskLevel, 255)

				, CONVERT(DECIMAL(18,2), SRC.ActualUsage ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineContractCost ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineContractMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineContractMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineContractRevenue ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineExpensesContractCost ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineExpensesContractMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineExpensesContractMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineExpensesContractRevenue ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineServicesContractCost ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineServicesContractMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineServicesContractMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineServicesContractRevenue ) 
				, CONVERT(DECIMAL(18,2), SRC.BaselineUsage ) 

				, CONVERT(DECIMAL(18,2), SRC.ContractCost ) 
				, CONVERT(DECIMAL(18,2), SRC.ContractMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.ContractMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.ContractRevenue ) 
				, CONVERT(DECIMAL(18,2), SRC.ExpensesContractCost ) 
				, CONVERT(DECIMAL(18,2), SRC.ExpensesContractMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.ExpensesContractMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.ExpensesContractRevenue ) 
				, CONVERT(DECIMAL(18,2), SRC.ExpensesSupplierInvoiceableAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.ForecastUsage ) 
				, CONVERT(DECIMAL(18,2), SRC.InvoicingCcyExpensesInvoiceableAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.InvoicingCcyServicesInvoiceableAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.InvoicingCurrencyContractRevenue ) 
				, SRC.InvoicingCurrencyIsoCode 

				, SRC.KC_IsActive
				, SRC.KC_IsWon
				, SRC.KC_Trigger

				, CONVERT(DECIMAL(18,2), SRC.ProposalItemsCostTotal ) 
				, CONVERT(DECIMAL(18,2), SRC.ProposalItemsMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.ProposalItemsMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.ServicesContractCost ) 
				, CONVERT(DECIMAL(18,2), SRC.ServicesContractMargin ) 
				, CONVERT(DECIMAL(18,2), SRC.ServicesContractMarginAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.ServicesContractRevenue ) 
				, CONVERT(DECIMAL(18,2), SRC.ServicesSupplierInvoiceableAmount ) 
				, CONVERT(DECIMAL(18,2), SRC.WeightedContractRevenue) 
				, CONVERT(DECIMAL(18,2), SRC.WhatIfDifference ) 

				, SRC.SharedWithCustomer 

				, SRC.UrlToKanataRevenuesAndCostsRecord
				, SRC.UrlToKanataRecord	

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
				SRC.DeliveryGroupBk, 
				SRC._crda_ActiveFromDateTime ; 


			/*Reassign lost FKs*/
			UPDATE	R 
			SET		AccountSk = ISNULL(K1.AccountSk , -1)
	--		SELECT		R.AccountSk , K1.AccountSk , K.AccountSk
			FROM	dbo.DimDeliveryGroup			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	HR	ON	HR.Id				= R.DeliveryGroupBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  

			LEFT JOIN	dbo.DimAccount		K	ON	K.AccountSk = R.AccountSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account	RU	ON	RU.Id						= HR.KimbleOne__Account__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount	K1	ON	K1.AccountBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.AccountSk IS NULL ; 


			UPDATE	R 
			SET		BillingAccountSk = ISNULL(K1.AccountSk , -1) 
	--		SELECT		R.BillingAccountSk , K1.AccountSk , K.AccountSk
			FROM	dbo.DimDeliveryGroup			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	HR	ON	HR.Id				= R.DeliveryGroupBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  
				
			LEFT JOIN dbo.DimAccount		K	ON	K.AccountSk = R.BillingAccountSk  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account	RU	ON	RU.Id						= HR.KimbleOne__Account__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount	K1	ON	K1.AccountBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.AccountSk IS NULL ; 

			UPDATE	R 
			SET		ForecastStatusSk = ISNULL(K1.ForecastStatusSk , -1) 
	--		SELECT		R.ForecastStatusSk , K1.ForecastStatusSk , K.ForecastStatusSk
			FROM	dbo.DimDeliveryGroup			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	HR	ON	HR.Id				= R.DeliveryGroupBk
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
			SET		ProposalSk = ISNULL(K1.ProposalSk , -1)
	--		SELECT		R.ProposalSk , K1.ProposalSk , K.ProposalSk
			FROM	dbo.DimDeliveryGroup			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	HR	ON	HR.Id				= R.DeliveryGroupBk
																			AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																			AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimProposal		K	ON	K.ProposalSk = R.ProposalSk  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	RU	ON	RU.Id						= HR.KimbleOne__Proposal__c 
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