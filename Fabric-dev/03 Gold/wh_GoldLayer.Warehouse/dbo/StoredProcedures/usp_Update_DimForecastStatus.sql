CREATE  
	PROCEDURE dbo.usp_Update_DimForecastStatus
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimForecastStatus]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimForecastStatus]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimForecastStatus]')
	EXEC dbo.usp_Update_DimForecastStatus @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	SELECT * FROM dbo.DimForecastStatus ; 
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

			TRUNCATE TABLE dbo.DimForecastStatus ; 

			INSERT INTO dbo.DimForecastStatus ( 
				ForecastStatusSk,ForecastStatusBk,[Name],ShortName,CurrencyIsoCode
					,Probability,Contingency,StyleClass,IsDelivery, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT ForecastStatusSk,ForecastStatusBk,[Name],ShortName,CurrencyIsoCode
					,Probability,Contingency,StyleClass,IsDelivery, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' , 'Unknown', 'ZZZ'
						,0, 0, 'UnknownRecord', NULL, 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	ForecastStatusSk,ForecastStatusBk,[Name],ShortName,CurrencyIsoCode
									,Probability,Contingency,StyleClass,IsDelivery, 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimForecastStatus B 
				WHERE	B.ForecastStatusSk = T.ForecastStatusSk 
			) ; 


			SELECT 
				 ForecastStatusBk	= T.Id
				,T.[Name]
				,ShortName			= ISNULL(T.Shortname__c, T.KC_ShortName__c)
				,T.CurrencyIsoCode 
				,Probability		= T.KimbleOne__Probability__c
				,Contingency		= T.KimbleOne__ContingencyPercentage__c
				,StyleClass			= ISNULL(T.KimbleOne__StyleClass__c, '')
				,IsDelivery			= T.KimbleOne__IsDelivery__c 
				,ProbabilityCode	= ISNULL(RD.[Name] , '') 
				, T._crda_ActiveFromDateTime 
				, T._crda_ActiveToDateTime 
				, AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	 T 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ReferenceData RD	ON	RD.Id = T.KimbleOne__ProbabilityCode__c	 
																		AND	T._crda_ActiveFromDateTime BETWEEN RD._crda_ActiveFromDateTime AND RD._crda_ActiveToDateTime 
																		AND	RD._crda_isDeleted = 0 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  T.[Name] 
							, T.Shortname__c 
							, T.KC_ShortName__c 
							, T.CurrencyIsoCode 
							, T.KimbleOne__Probability__c 
							, T.KimbleOne__ContingencyPercentage__c 
							, T.KimbleOne__StyleClass__c 
							, T.KimbleOne__IsDelivery__c 
							, ISNULL(RD.[Name] , '') --ProbabilityCode 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark 
			AND		T._crda_isDeleted = 0 


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'ForecastStatus';

			INSERT INTO dbo.DimForecastStatus(
				ForecastStatusSk , 
				ForecastStatusBk , 
				[Name]	, 
				ShortName	, 
				CurrencyIsoCode	, 
				Probability	, 
				Contingency	, 
				StyleClass	, 
				IsDelivery	, 
				ProbabilityCode 

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
				--ROW_NUMBER()OVER (PARTITION BY SRC.ForecastStatusBk ORDER BY SRC._crda_ActiveFromDateTime) , 
				ROW_NUMBER()OVER (ORDER BY SRC._crda_ActiveFromDateTime) , 
				SRC.ForecastStatusBk , 
				SRC.[Name]	, 
				SRC.ShortName	, 
				SRC.CurrencyIsoCode	, 
				SRC.Probability	, 
				SRC.Contingency	, 
				SRC.StyleClass	, 
				SRC.IsDelivery	, 
				SRC.ProbabilityCode 

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
			ORDER BY	SRC._crda_ActiveFromDateTime ;


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