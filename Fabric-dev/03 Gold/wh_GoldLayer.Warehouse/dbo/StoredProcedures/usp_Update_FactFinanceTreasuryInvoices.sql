CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactFinanceTreasuryInvoices
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactFinanceTreasuryInvoices]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactFinanceTreasuryInvoices]' )
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactFinanceTreasuryInvoices]' )
	EXEC dbo.usp_Update_FactFinanceTreasuryInvoices @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactFinanceTreasuryInvoices ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters 
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) ,
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);


	BEGIN TRY

		BEGIN TRANSACTION 


			TRUNCATE TABLE dbo.FactFinanceTreasuryInvoices ;

			INSERT INTO dbo.FactFinanceTreasuryInvoices
			(	
				 DocumentType
				,InvoiceDate
				,DueDate
				,ExcludeFromCashflowUntil

				,AccountSk	
				,ExchangeRateSk	
				,DeliveryElementSk
				,CurrencyCode	

				,TaxCode
				,Exclude

				,Amount	
				,AmountLCYExcVAT
				,AmountLCYIncVAT

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)

			/*[Kimble].[vw_FinanceTreasury_CashInInvoiceable]*/
			SELECT		
				DocumentType		= 'CashInInvoiceable' ,
				I.InvoiceDate , 
				DueDate				= CASE
										WHEN InvoiceDate < CAST(GETUTCDATE() AS DATE) THEN DATEADD(DAY,AC.InvoicePaymentTermDays,CAST(GETUTCDATE() AS DATE))
										ELSE DATEADD(DAY,AC.InvoicePaymentTermDays,InvoiceDate) 
										END ,
				ExcludeFromCashflowUntil= ISNULL(DE.ExcludeFromCashflowUntil,'2001-01-01') , 

				AccountSk			= ISNULL(AC.AccountSk, -1 ) ,
				ExchangeRateSk		= COALESCE(ER.ExchangeRateSk, ER1.ExchangeRateSk,-1) , 
				DeliveryElementSk	= ISNULL(DE.DeliveryElementSk, -1) , 

				CurrencyCode		= I.CurrencyIsoCode ,
				TaxCode				=	CASE
											WHEN DE.TaxCodeBk  = 'a1oD0000000LBLuIAO' THEN 20 
											WHEN DE.TaxCodeBk  IN ('a1oD0000000LBLyIAO','a1oD0000000LK8jIAG') THEN 0
											WHEN ISNULL(DE.TaxCodeBk,'')  = '' THEN 0 
											ELSE 0 
										END ,
				Exclude				= IIF( ISNULL(DE.ExcludeFromCashflowUntil,'2001-01-01') >= I.InvoiceDate, 1, 0 ) ,
	
				Amount ,
 				AmountLCYExcVAT	= Amount/ISNULL(ER.ConversionFactorRate ,ER1.ConversionFactorRate) ,
				AmountLCYIncVAT	= (Amount/ISNULL(ER.ConversionFactorRate ,ER1.ConversionFactorRate)) 
									*( 1 + (
										CASE
											WHEN DE.TaxCodeBk  = 'a1oD0000000LBLuIAO' THEN 20.00 
											WHEN DE.TaxCodeBk  IN ('a1oD0000000LBLyIAO','a1oD0000000LK8jIAG') THEN 0
											WHEN ISNULL(DE.TaxCodeBk,'')  = '' THEN 0 
											ELSE 0 
										END/100)
									)
				,_crda_CreatedExecutionId	= @_ExecutionId 
				,_crda_CreatedDateTime		= GETUTCDATE() 
			
			FROM		(
							SELECT
								DeliveryElementBk = I.KimbleOne__DeliveryElement__c,
								I.CurrencyIsoCode ,
								InvoiceDate			= EOMONTH(I.KimbleOne__InvoiceItemDate__c,0) ,
								Amount				= SUM(I.KimbleOne__InvoiceableAmount__c) 
							FROM	lh_SilverLayer.Kantata.HISTORY_InvoiceableItem I
							WHERE	I._crda_isDeleted				= 0 
							AND		I._crda_ActiveToDateTime		= '9999-12-31 23:59:59'  
							AND		I.KimbleOne__InvoiceableAmount__c <> 0 
							AND		I._crda_ActiveFromDateTime		>= @_Watermark
							GROUP BY
								I.KimbleOne__DeliveryElement__c,
								I.CurrencyIsoCode ,
								EOMONTH(I.KimbleOne__InvoiceItemDate__c,0)
						)								I 

			LEFT JOIN	dbo.DimDeliveryElement			DE	ON	DE.DeliveryElementBk	= I.DeliveryElementBk
															AND	DE.IsCurrent			= 1 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	DE1	ON	DE1.Id					= I.DeliveryElementBk 
															AND DE1._crda_isDeleted		= 0  
															AND	DE1._crda_ActiveToDateTime= '9999-12-31 23:59:59'  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	DG	ON	DG.Id					= DE1.KimbleOne__DeliveryGroup__c 
															AND DG._crda_isDeleted		= 0 
															AND	DG._crda_ActiveToDateTime= '9999-12-31 23:59:59'  

			LEFT JOIN	dbo.DimAccount					AC	ON	AC.AccountBk = 
																CASE
																	WHEN DE1.KimbleOne__BillingAccount__c <> '' THEN DE1.KimbleOne__BillingAccount__c 
																	WHEN DG.KimbleOne__BillingAccount__c <> '' THEN DG.KimbleOne__BillingAccount__c 
																	ELSE DG.KimbleOne__Account__c 
																END
															AND	AC.IsCurrent	= 1 

			LEFT JOIN	dbo.DimExchangeRate				ER	ON	ER.CurrencyIsoCode	= I.CurrencyIsoCode 
															AND	I.InvoiceDate BETWEEN ER.RateEffectiveStartDate AND ER.RateEffectiveEndDate 

			LEFT JOIN	(
							SELECT	ExchangeRateSk, CurrencyIsoCode, ConversionFactorRate ,
									RN = ROW_NUMBER()OVER(PARTITION BY CurrencyIsoCode ORDER BY RateEffectiveStartDate DESC)
							FROM	dbo.DimExchangeRate 
						)								ER1	ON	ER1.CurrencyIsoCode	= I.CurrencyIsoCode 
															AND	ER1.RN  = 1 
			WHERE	(ISNULL(DE.ExcludeFromCashflowUntil,'2001-01-01') < InvoiceDate) 

			UNION ALL 

			/*[Kimble].[vw_FinanceTreasury_CashInInvoiced]*/
			SELECT		
				DocumentType		= 'CashInInvoiced' ,
				I.InvoiceDate , 
				DueDate				= CASE
										WHEN InvoiceDate < CAST(GETUTCDATE() AS DATE) THEN DATEADD(DAY,AC.InvoicePaymentTermDays,CAST(GETUTCDATE() AS DATE))
										ELSE DATEADD(DAY,AC.InvoicePaymentTermDays,InvoiceDate) 
										END ,
				ExcludeFromCashflowUntil= ISNULL(DE.ExcludeFromCashflowUntil,'2001-01-01') , 

				AccountSk			= ISNULL(AC.AccountSk, -1 ) ,
				ExchangeRateSk		= COALESCE(ER.ExchangeRateSk, ER1.ExchangeRateSk,-1) , 
				DeliveryElementSk	= ISNULL(DE.DeliveryElementSk, -1) , 

				CurrencyCode		= I.CurrencyIsoCode ,
				TaxCode				=	CASE
											WHEN DE.TaxCodeBk  = 'a1oD0000000LBLuIAO' THEN 20 
											WHEN DE.TaxCodeBk  IN ('a1oD0000000LBLyIAO','a1oD0000000LK8jIAG') THEN 0
											WHEN ISNULL(DE.TaxCodeBk,'')  = '' THEN 0 
											ELSE 0 
										END ,
				Exclude				= IIF( ISNULL(DE.ExcludeFromCashflowUntil,'2001-01-01') >= I.InvoiceDate, 1, 0 ) ,
	
				Amount ,
 				AmountLCYExcVAT	= Amount/ISNULL(ER.ConversionFactorRate ,ER1.ConversionFactorRate) ,
				AmountLCYIncVAT	= (Amount/ISNULL(ER.ConversionFactorRate ,ER1.ConversionFactorRate)) 
									*( 1 + (
										CASE
											WHEN DE.TaxCodeBk  = 'a1oD0000000LBLuIAO' THEN 20.00 
											WHEN DE.TaxCodeBk  IN ('a1oD0000000LBLyIAO','a1oD0000000LK8jIAG') THEN 0
											WHEN ISNULL(DE.TaxCodeBk,'')  = '' THEN 0 
											ELSE 0 
										END/100)
									)
				,_crda_CreatedExecutionId	= @_ExecutionId 
				,_crda_CreatedDateTime		= GETUTCDATE() 
			
			FROM		(
							SELECT
								DeliveryElementBk	= KII.KimbleOne__DeliveryElement__c ,
								KI.CurrencyIsoCode , 
								InvoiceDate	= EOMONTH(KimbleOne__InvoiceItemDate__c,0) ,
								Amount		= SUM(KII.KimbleOne__InvoicedAmount__c) 
							FROM		lh_SilverLayer.Kantata.HISTORY_Invoice			KI
							LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_InvoiceLine		KIL	 ON KIL.KimbleOne__Invoice__c = KI.Id 
																				AND KIL._crda_isDeleted			= 0 
																				AND KIL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

							LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_InvoiceLineItem	KILI ON KILI.KimbleOne__InvoiceLine__c = KIL.Id 
																				AND KILI._crda_isDeleted			= 0 
																				AND KILI._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

							LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_InvoiceableItem	KII  ON KILI.KimbleOne__InvoiceableItem__c = KII.Id 
																				AND KII._crda_isDeleted			= 0 
																				AND KII._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

							WHERE	KI._crda_isDeleted			= 0  
							AND		KI.KimbleOne__OutboundInterfaceRun__c IS NULL 
							AND		KI._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
							AND		KI._crda_ActiveFromDateTime		>= @_Watermark

							GROUP BY 
								KII.KimbleOne__DeliveryElement__c ,
								KI.CurrencyIsoCode , 
								EOMONTH(KimbleOne__InvoiceItemDate__c,0)  
						)								I 

			LEFT JOIN	dbo.DimDeliveryElement			DE	ON	DE.DeliveryElementBk	= I.DeliveryElementBk
															AND	DE.IsCurrent			= 1 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryElement	DE1	ON	DE1.Id					= I.DeliveryElementBk 
															AND DE1._crda_isDeleted		= 0  
															AND	DE1._crda_ActiveToDateTime= '9999-12-31 23:59:59'  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	DG	ON	DG.Id					= DE1.KimbleOne__DeliveryGroup__c 
															AND DG._crda_isDeleted		= 0 
															AND	DG._crda_ActiveToDateTime= '9999-12-31 23:59:59'  

			LEFT JOIN	dbo.DimAccount					AC	ON	AC.AccountBk = 
																CASE
																	WHEN DE1.KimbleOne__BillingAccount__c <> '' THEN DE1.KimbleOne__BillingAccount__c 
																	WHEN DG.KimbleOne__BillingAccount__c <> '' THEN DG.KimbleOne__BillingAccount__c 
																	ELSE DG.KimbleOne__Account__c 
																END
															AND	AC.IsCurrent	= 1 

			LEFT JOIN	dbo.DimExchangeRate				ER	ON	ER.CurrencyIsoCode	= I.CurrencyIsoCode 
															AND	I.InvoiceDate BETWEEN ER.RateEffectiveStartDate AND ER.RateEffectiveEndDate 

			LEFT JOIN	(
							SELECT	ExchangeRateSk, CurrencyIsoCode, ConversionFactorRate ,
									RN = ROW_NUMBER()OVER(PARTITION BY CurrencyIsoCode ORDER BY RateEffectiveStartDate DESC)
							FROM	dbo.DimExchangeRate 
						)								ER1	ON	ER1.CurrencyIsoCode	= I.CurrencyIsoCode 
															AND	ER1.RN  = 1 
			WHERE	(ISNULL(DE.ExcludeFromCashflowUntil,'2001-01-01') < InvoiceDate) ;


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