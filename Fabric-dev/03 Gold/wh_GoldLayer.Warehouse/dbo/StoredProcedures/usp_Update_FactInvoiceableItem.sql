CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactInvoiceableItem
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactInvoiceableItem]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactInvoiceableItem]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactInvoiceableItem]')
	EXEC dbo.usp_Update_FactInvoiceableItem @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM [dbo].[FactInvoiceableItem] ; --150560
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

			DROP TABLE IF EXISTS #Source ;

			SELECT	 
				  DI.InvoiceableItemSk 
				, ResourceSk				= ISNULL(DR.ResourceSk, -1) 
				, DeliveryElementSk			= ISNULL(DE.DeliveryElementSk, -1) 
				, DeliveryGroupSk			= DE.DeliveryGroupSk 
				, DeliveryGroupAccountSk	= DG.AccountSk 
				, AccountBusinessUnitSk		= AC.BusinessUnitSk 
				, OriginatingProposalSk		= DE.OriginatingProposalSk 
				, ProposalBusinessUnitSk	= ISNULL(PR.BusinessUnitSk , -1) 
				, MilestoneSk				= ISNULL(MS.MilestoneSk, -1)
				, DemandBusinessUnitSk		= ISNULL(DBU.BusinessUnitSk, -1) 
				, SupplyBusinessUnitSk		= ISNULL(SBU.BusinessUnitSk, -1) 
				, ExchangeRateSk			= ISNULL(ER1.ExchangeRateSk, -1) 

				, InvoiceItemDate			= CAST(T.KimbleOne__InvoiceItemDate__c AS DATE)
				, InvoiceItemDateEom		= EOMONTH(T.KimbleOne__InvoiceItemDate__c) 
				, IsFuturePeriod			= IIF(CAST(EOMONTH(T.KimbleOne__InvoiceItemDate__c) AS DATE)< CAST(GETUTCDATE() AS DATE) , 0, 1 ) 

				, InvoiceableAmount			= T.KimbleOne__InvoiceableAmount__c
				, InvoicedAmount			= T.KimbleOne__InvoicedAmount__c
				, [InvoiceableAmountLCY]	= CAST(ISNULL(T.KimbleOne__InvoiceableAmount__c / NULLIF(ER1.ConversionFactorRate,0),0) AS DECIMAL(18,2))
				, NirAmount					= CAST(
												IIF(INV.Id IS NULL, 
													T.KimbleOne__InvoiceableAmount__c/ER1.ConversionFactorRate 
														, T.[KimbleOne__InvoicedAmount__c]/ ER1.ConversionFactorRate
													) AS DECIMAL (18,2)
												) 
				, ExpensesInvoiceableAmount	= T.KimbleOne__ExpensesInvoiceableAmount__c
				, ServicesInvoiceableAmount	= T.KimbleOne__ServicesInvoiceableAmount__c 
				,T._crda_ActiveFromDateTime

			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_InvoiceableItem	T	
			INNER JOIN	dbo.DimInvoiceableItem		DI	ON	DI.InvoiceableItemBk= T.Id 
														AND	DI.IsCurrent		= 1 
			LEFT JOIN	(
							SELECT	ExchangeRateSk, CurrencyIsoCode, ConversionFactorRate ,
									RN = ROW_NUMBER()OVER(PARTITION BY CurrencyIsoCode ORDER BY RateEffectiveStartDate DESC)
							FROM	dbo.DimExchangeRate 
						)								ER1	ON	ER1.CurrencyIsoCode	= T.CurrencyIsoCode 
															AND	ER1.RN  = 1 

			LEFT JOIN	(
							SELECT  IV.Id,
									InvoiceableItemBk = ILI.KimbleOne__InvoiceableItem__c
							FROM lh_SilverLayer.Kantata.HISTORY_Invoice				IV
							LEFT JOIN KIMBLE.HISTORY_InvoiceLine	IL	ON	IV.ID =	IL.KimbleOne__Invoice__c 
																		AND	IL._crda_isDeleted			= 0 
																		AND	IL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
							LEFT JOIN lh_SilverLayer.Kantata.HISTORY_InvoiceLineItem ILI	ON	ILI.KimbleOne__InvoiceLine__c	= IL.ID
																			AND ILI._crda_isDeleted			= 0 
																			AND	ILI._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
							WHERE	IV._crda_ActiveFromDateTime > @_Watermark  
							AND		IV.KimbleOne__OutboundInterfaceRun__c IS NULL 
							AND		IV._crda_isDeleted			= 0 
							AND		IV._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

						)								INV	ON	INV.InvoiceableItemBk	= T.Id 

			LEFT JOIN	dbo.DimDeliveryElement			DE	ON	DE.DeliveryElementBk = T.KimbleOne__DeliveryElement__c 
															AND	DE.IsCurrent = 1

			LEFT JOIN	dbo.DimDeliveryGroup			DG	ON	DG.DeliveryGroupSk	= DE.DeliveryGroupSk 

			LEFT JOIN	dbo.DimAccount					AC	ON	AC.AccountSk		= DG.AccountSk 

			LEFT JOIN	dbo.DimProposal					PR	ON	PR.ProposalSk		= DE.ProposalSk 

			LEFT JOIN	dbo.DimMilestone				MS	ON	MS.MilestoneBk		= T.KimbleOne__Milestone__c 
															AND	MS.IsCurrent = 1

			LEFT JOIN	dbo.DimBusinessUnit				DBU	ON	DBU.BusinessUnitBk	= T.KimbleOne__DemandBusinessUnit__c 
															AND	DBU.IsCurrent = 1

			LEFT JOIN	dbo.DimBusinessUnit				SBU	ON	SBU.BusinessUnitBk	= T.KimbleOne__SupplyBusinessUnit__c 
															AND	SBU.IsCurrent = 1

			LEFT JOIN	dbo.DimResource					DR	ON	DR.ResourceBk	= T.Resource__c 
															AND	DR.IsCurrent = 1
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			--AND		(INV.Id IS NOT NULL) OR (T.KimbleOne__InvoiceableAmount__c <> 0 )
			AND		T._crda_isDeleted = 0 
			AND		T._crda_ActiveToDateTime	= '99991231'; 



			TRUNCATE TABLE dbo.FactInvoiceableItem ;

			INSERT INTO dbo.FactInvoiceableItem
			(
				 InvoiceableItemSk
				,ResourceSk
				,DeliveryElementSk
				,DeliveryGroupSk
				,DeliveryGroupAccountSk
				,AccountBusinessUnitSk
				,OriginatingProposalSk
				,ProposalBusinessUnitSk
				,MilestoneSk
				,DemandBusinessUnitSk
				,SupplyBusinessUnitSk
				,ExchangeRateSk
				,InvoiceItemDate
				,InvoiceItemDateEom
				,IsFuturePeriod
				,InvoiceableAmount
				,InvoicedAmount
				,InvoiceableAmountLCY
				,NirAmount
				,ExpensesInvoiceableAmount
				,ServicesInvoiceableAmount
				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 SRC.InvoiceableItemSk
				,SRC.ResourceSk
				,SRC.DeliveryElementSk
				,SRC.DeliveryGroupSk
				,SRC.DeliveryGroupAccountSk
				,SRC.AccountBusinessUnitSk
				,SRC.OriginatingProposalSk
				,SRC.ProposalBusinessUnitSk
				,SRC.MilestoneSk
				,SRC.DemandBusinessUnitSk
				,SRC.SupplyBusinessUnitSk
				,SRC.ExchangeRateSk
				,SRC.InvoiceItemDate
				,SRC.InvoiceItemDateEom
				,SRC.IsFuturePeriod
				,SRC.InvoiceableAmount
				,SRC.InvoicedAmount
				,SRC.InvoiceableAmountLCY
				,SRC.NirAmount
				,SRC.ExpensesInvoiceableAmount
				,SRC.ServicesInvoiceableAmount

				,@_ExecutionId  
				,GETUTCDATE() 
			FROM		#Source	SRC 


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