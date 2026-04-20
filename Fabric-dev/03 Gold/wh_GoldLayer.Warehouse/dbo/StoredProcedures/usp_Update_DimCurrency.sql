CREATE   
	PROCEDURE dbo.usp_Update_DimCurrency
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimCurrency]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimCurrency]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimCurrency]')
	EXEC dbo.usp_Update_DimCurrency @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	SELECT * FROM dbo.DimCurrency ; 
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

			TRUNCATE TABLE dbo.DimCurrency ; 

			INSERT INTO dbo.DimCurrency ( 
				CurrencySk, CurrencyBk, Currency, CurrencyCountry, CurrencyIsoCode, CurrencyIsoNumber, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT CurrencySk, CurrencyBk, Currency, CurrencyCountry, CurrencyIsoCode, CurrencyIsoNumber, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'ZZZ' , 'UnknownRecord' , 'Unknown', 'ZZZ','ZZZ', 
								'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
									,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	CurrencySk,CurrencyBk,Currency,CurrencyCountry,CurrencyIsoCode,CurrencyIsoNumber, 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimCurrency B 
				WHERE	B.CurrencySk = T.CurrencySk 
			) ; 


			;WITH cteSource
			AS(
				SELECT	CurrencyBk			=	T.CurrencyIsoCode ,
						Currency			=	ISNULL(C.CurrencyName, 'UnknownZZZ') , 
						CurrencyCountry		=	ISNULL(C.CurrencyCountry, 'UnknownZZZ') , 
						T.CurrencyIsoCode ,
						CurrencyIsoNumber	= T.[Name] , 

						_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
						_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
						T._crda_isDeleted 
				FROM		lh_SilverLayer.Kantata.History_ExchangeRate	T 
				LEFT JOIN	dbo.CurrencyLookup ()		C	ON	C.CurrencyIsoCode = T.CurrencyIsoCode

				WHERE	T._crda_ActiveFromDateTime		> @_Watermark 
				AND		T._crda_ActiveToDateTime		= '9999-12-31 23:59:59' 
				AND		T._crda_isDeleted				= 0 
				AND		T.KimbleOne__EffectiveToDate__c IS NULL 
			)
			SELECT 
					T.CurrencyBk ,
					T.Currency , 
					T.CurrencyCountry ,
					T.CurrencyIsoCode , 
					T.CurrencyIsoNumber ,
					T._crda_ActiveFromDateTime , 
					T._crda_ActiveToDateTime, 
					AD._crda_Hash 
			INTO #Source 
			FROM cteSource T 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.Currency 
								, T.CurrencyCountry 
								, T.CurrencyIsoNumber 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD ;


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Currency';


			INSERT INTO dbo.DimCurrency(
				CurrencySk , 
				CurrencyBk , 
				Currency , 
				CurrencyCountry	, 
				CurrencyIsoCode	, 
				CurrencyIsoNumber  

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
				RN= ROW_NUMBER()OVER (PARTITION BY SRC.CurrencyBk  ORDER BY SRC._crda_ActiveFromDateTime) , 
				SRC.CurrencyBk , 
				SRC.Currency	, 
				SRC.CurrencyCountry	, 
				SRC.CurrencyIsoCode	, 
				SRC.CurrencyIsoNumber 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM 	#Source	SRC 
			ORDER BY SRC.CurrencyBk, SRC._crda_ActiveFromDateTime ; 

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