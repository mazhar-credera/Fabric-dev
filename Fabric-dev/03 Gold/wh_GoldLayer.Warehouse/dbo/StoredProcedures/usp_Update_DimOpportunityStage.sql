CREATE   
	PROCEDURE dbo.usp_Update_DimOpportunityStage
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimOpportunityStage]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimOpportunityStage]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimOpportunityStage]')
	EXEC dbo.usp_Update_DimOpportunityStage @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT count(1) FROM dbo.DimOpportunityStage ; 
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

			TRUNCATE TABLE dbo.DimOpportunityStage ; 

			INSERT INTO dbo.DimOpportunityStage ( 
				OpportunityStageSk, OpportunityStageBk, [Name], [Description] , [Sequence], SequencedName , 
					CurrencyIsoCode, RequiresDeliveryElementForecast, DefaultForecastStatus, RequiresCompletionApproval , 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT OpportunityStageSk, OpportunityStageBk, [Name], [Description] , [Sequence], SequencedName , 
						CurrencyIsoCode, RequiresDeliveryElementForecast, DefaultForecastStatus, RequiresCompletionApproval , 
							_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
								,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' , '', 0, '', 'ZZZ', 0, '', 0 , 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	OpportunityStageSk, OpportunityStageBk, [Name], [Description] , [Sequence], SequencedName , 
									CurrencyIsoCode, RequiresDeliveryElementForecast, DefaultForecastStatus, RequiresCompletionApproval , 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimOpportunityStage B 
				WHERE	B.OpportunityStageSk = T.OpportunityStageSk 
			) ; 


			SELECT	OpportunityStageBk		= T.Id , 
					T.[Name], 
					[Description]			= ISNULL(T.[KimbleOne__Description__c] , '') , 
					[Sequence]				= T.KimbleOne__Sequence__c , 
					SequencedName			= T.KimbleOne__SequencedName__c , 
					T.CurrencyIsoCode , 
					RequiresDeliveryElementForecast	= T.KimbleOne__RequiresDeliveryElementForecast__c , 
					DefaultForecastStatus			= ISNULL(F.[Name] , '') , 
					RequiresCompletionApproval		= T.KimbleOne__RequiresCompletionApproval__c , 
					_crda_ActiveFromDateTime		= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime			= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_OpportunityStage		T 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	F	ON	F.Id = T.KimbleOne__DefaultForecastStatus__c 
															AND F._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
															AND	F._crda_isDeleted = 0
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.[Name]		
								, T.[KimbleOne__Description__c]	 
								, T.KimbleOne__Sequence__c	
								, T.KimbleOne__SequencedName__c	
								, T.CurrencyIsoCode	
								, T.KimbleOne__RequiresDeliveryElementForecast__c	
								, F.[Name]	
								, T.KimbleOne__RequiresCompletionApproval__c	
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 
			ORDER BY [Sequence] ; 


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'OpportunityStage';


			INSERT INTO dbo.DimOpportunityStage
			(
				OpportunityStageSk , 
				OpportunityStageBk , 
				[Name] , 
				[Description] , 
				[Sequence] , 
				SequencedName , 
				CurrencyIsoCode , 
				RequiresDeliveryElementForecast , 
				DefaultForecastStatus , 
				RequiresCompletionApproval 

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
				ROW_NUMBER()OVER (ORDER BY SRC.OpportunityStageBk, SRC._crda_ActiveFromDateTime) , 
				SRC.OpportunityStageBk , 
				SRC.[Name] , 
				SRC.[Description] , 
				SRC.[Sequence] , 
				SRC.SequencedName , 
				SRC.CurrencyIsoCode , 
				SRC.RequiresDeliveryElementForecast , 
				SRC.DefaultForecastStatus , 
				SRC.RequiresCompletionApproval 

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
			ORDER BY SRC.OpportunityStageBk, SRC._crda_ActiveFromDateTime ; 


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