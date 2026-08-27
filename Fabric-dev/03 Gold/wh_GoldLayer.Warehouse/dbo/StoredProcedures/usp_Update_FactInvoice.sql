CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_FactInvoice
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	GroundhogDay Load 

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactInvoice]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactInvoice]' )
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactInvoice]' )
	EXEC dbo.usp_Update_FactInvoice @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactInvoice ; 
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

			DROP TABLE IF EXISTS #Src ;

			SELECT
				 InvoiceBk			= KI.Id 
				,PeriodStartDate	= CAST(CP.KimbleOne__StartDate__c AS DATE) 
				,PeriodEndDate		= CAST(CP.KimbleOne__EndDate__c AS DATE) 
				,InvoiceDate		= CAST(KI.KimbleOne__InvoiceDate__c AS DATE) 
				,InvoiceDueDate		= CAST(KI.KimbleOne__InvoiceDueDate__c AS DATE) 
				,InvoiceNo			= KI.KimbleOne__Reference__c 

				,AccountSk			= ISNULL(A.AccountSk, -1) 
				,AccountBusinessUnitSk		= ISNULL(A.BusinessUnitSk, -1) 
				,TradingEntityBusinessUnitSk= ISNULL(TBU.BusinessUnitSk, -1) 
				,InvoiceStatusSk			= ISNULL(IVS.InvoiceStatusSk, -1) 
				,ExchangeRateSk				= COALESCE(ER.ExchangeRateSk, ER1.ExchangeRateSk,-1) 

				,KI.CurrencyIsoCode 
				,TotalGrossAmount	= KI.KimbleOne__GrossAmount__c 
				,TotalNetAmount		= KI.KimbleOne__NetAmount__c 
				,TotalTaxAmount		= KI.KimbleOne__TaxAmount__c 
				,TaxRate			= KI.KimbleOne__TaxRate__c 

				,TotalCreditedGrossAmount= KI.KimbleOne__CreditedGrossAmount__c 
				,TotalCreditedNetAmount	= KI.KimbleOne__CreditedNetAmount__c 

				,OutboundInterfaceRunFg	= IIF(KimbleOne__OutboundInterfaceRun__c IS NULL, 0, 1)

				,KI._crda_ActiveFromDateTime 

			INTO #Src
			FROM		lh_SilverLayer.Kantata.HISTORY_Invoice			KI	

			LEFT JOIN	dbo.DimInvoiceStatus			IVS	ON	IVS.InvoiceStatusBk		= KI.KimbleOne__Status__c 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ReferenceData	RD	ON	RD.Id				= KI.KimbleOne__Status__c
															AND RD._crda_isDeleted	= 0 
															AND	RD._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePeriod		CP 	ON	CP.Id				= KI.KimbleOne__ForecastingTimePeriod__c
															AND CP._crda_isDeleted	= 0  
															AND	CP._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			LEFT JOIN	dbo.DimAccount					A	ON	A.AccountBk			= KI.KimbleOne__Account__c
															AND A.IsCurrent			= 1 

			LEFT JOIN	dbo.DimBusinessUnit				TBU	ON	TBU.BusinessUnitBk	= KI.KimbleOne__BusinessUnitTradingEntity__c
															AND TBU.IsCurrent		= 1 

			LEFT JOIN	dbo.DimExchangeRate				ER	ON	ER.CurrencyIsoCode	= KI.CurrencyIsoCode 
															AND	KI.KimbleOne__InvoiceDate__c BETWEEN ER.RateEffectiveStartDate AND ER.RateEffectiveEndDate 

			LEFT JOIN	(
							SELECT	ExchangeRateSk, CurrencyIsoCode, ConversionFactorRate ,
									RN = ROW_NUMBER()OVER(PARTITION BY CurrencyIsoCode ORDER BY RateEffectiveStartDate DESC)
							FROM	dbo.DimExchangeRate 
						)								ER1	ON	ER1.CurrencyIsoCode	= KI.CurrencyIsoCode 
															AND	ER1.RN  = 1 

			WHERE	KI._crda_isDeleted = 0
			AND		KI._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			AND		KI._crda_ActiveFromDateTime	>= @_Watermark
			/*SELECT * FROM #Src ORDER BY PeriodStartDate, InvoiceDate*/

			TRUNCATE TABLE dbo.FactInvoice ; 

			INSERT INTO dbo.FactInvoice
			( 
				 PeriodStartDate
				,PeriodEndDate
				,InvoiceDate
				,InvoiceDueDate
				,InvoiceNo

				,AccountSk
				,AccountBusinessUnitSk
				,TradingEntityBusinessUnitSk
				,InvoiceStatusSk 
				,ExchangeRateSk

				,CurrencyCode
				,TotalGrossAmount
				,TotalNetAmount
				,TotalTaxAmount
				,TaxRate
				,TotalCreditedGrossAmount
				,TotalCreditedNetAmount

				,OutboundInterfaceRunFg

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 S.PeriodStartDate
				,S.PeriodEndDate
				,S.InvoiceDate
				,S.InvoiceDueDate
				,S.InvoiceNo

				,S.AccountSk
				,S.AccountBusinessUnitSk
				,S.TradingEntityBusinessUnitSk
				,S.InvoiceStatusSk 
				,S.ExchangeRateSk

				,S.CurrencyIsoCode 
				,S.TotalGrossAmount
				,S.TotalNetAmount
				,S.TotalTaxAmount
				,S.TaxRate
				,S.TotalCreditedGrossAmount
				,S.TotalCreditedNetAmount

				,S.OutboundInterfaceRunFg

				,@_ExecutionId 
				,GETUTCDATE() 
			FROM  #Src	S

			ORDER BY 
				 S.PeriodStartDate 
				,S.InvoiceDate ;

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Src S ;

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