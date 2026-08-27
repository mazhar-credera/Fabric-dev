CREATE  
	PROCEDURE dbo.usp_Update_DimExchangeRate
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimExchangeRate]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimExchangeRate]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimExchangeRate]')
	EXEC dbo.usp_Update_DimExchangeRate @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimExchangeRate ORDER BY ExchangeRateSk; 
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

			TRUNCATE TABLE dbo.DimExchangeRate ; 

			INSERT INTO dbo.DimExchangeRate ( 
				ExchangeRateSk, CurrencyIsoCode, RateEffectiveStartDate, RateEffectiveEndDate, ConversionFactorRate
					,_crda_Hash, _crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			SELECT	ExchangeRateSk, CurrencyIsoCode, RateEffectiveStartDate, RateEffectiveEndDate, ConversionFactorRate
						,_crda_Hash, _crda_CreatedExecutionId, _crda_CreatedDateTime 

			FROM	(VALUES	(	
					-1 , 'ZZZ', '20000101', '20000101', 0, 
						0x00, @_ExecutionId, GETUTCDATE()  ) 
					)	AS T(	ExchangeRateSk, CurrencyIsoCode, RateEffectiveStartDate, RateEffectiveEndDate, ConversionFactorRate
									,_crda_Hash, _crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimExchangeRate B 
				WHERE	B.ExchangeRateSk = T.ExchangeRateSk 
			) ; 

		SELECT 
			 ER.CurrencyIsoCode
			,RateEffectiveStartDate	= ER.KimbleOne__EffectiveDate__c 
			,RateEffectiveEndDate	= IIF(ER.CurrencyIsoCode = 'GBP', DATEADD(MILLISECOND, -3, CAST(EOMONTH(GETUTCDATE() ) AS DATETIME) ), DATEADD(MILLISECOND, -3, DATEADD(MONTH, 1, ER.KimbleOne__EffectiveDate__c) ) ) 
			,ConversionFactorRate	= ER.KimbleOne__ConversionFactor__c 
			,_crda_ActiveFromDateTime= CONVERT(DATETIME2(6),ER._crda_ActiveFromDateTime) 
			,_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), ER._crda_ActiveToDateTime) 
			,AD._crda_Hash 
			,RN = ROW_NUMBER()OVER (PARTITION BY ER.CurrencyIsoCode, ER.KimbleOne__EffectiveDate__c ORDER BY ER.CurrencyIsoCode, ER.KimbleOne__EffectiveDate__c)
		INTO #Source 
		FROM lh_SilverLayer.Kantata.HISTORY_ExchangeRate ER 
		CROSS APPLY (
			SELECT
			CAST(HASHBYTES('MD5',
				CONCAT_WS('||',	
						  IIF(ER.CurrencyIsoCode = 'GBP', DATEADD(MILLISECOND, -3, CAST(EOMONTH(GETUTCDATE() ) AS DATETIME) ), DATEADD(MILLISECOND, -3, DATEADD(MONTH, 1, ER.KimbleOne__EffectiveDate__c) ) ) 
						, ER.KimbleOne__ConversionFactor__c	 
					) 
				) AS VARBINARY(16)) AS _crda_Hash
			)  AD 
		WHERE	ER._crda_ActiveFromDateTime > @_Watermark  
		AND		ER._crda_isDeleted = 0 
		AND		ER._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  ;

/*		SELECT * FROM #Src
		SELECT * FROM dbo.DimExchangeRate ;		*/

		INSERT INTO	dbo.DimExchangeRate 
		( 
			 ExchangeRateSk 
			,CurrencyIsoCode
			,RateEffectiveStartDate
			,RateEffectiveEndDate 
			,ConversionFactorRate
			,_crda_Hash
			,_crda_CreatedExecutionId
			,_crda_CreatedDateTime
		)
		SELECT 
			 ROW_NUMBER()OVER (ORDER BY SRC.CurrencyIsoCode, SRC.RateEffectiveStartDate)
			,SRC.CurrencyIsoCode 
			,SRC.RateEffectiveStartDate 
			,SRC.RateEffectiveEndDate 
			,SRC.ConversionFactorRate 
			,SRC._crda_Hash
			,@_ExecutionId 
			,GETUTCDATE() 
		FROM	#Source SRC 
		WHERE	RN = 1 
		ORDER BY 
			SRC.CurrencyIsoCode, SRC.RateEffectiveStartDate ; 

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