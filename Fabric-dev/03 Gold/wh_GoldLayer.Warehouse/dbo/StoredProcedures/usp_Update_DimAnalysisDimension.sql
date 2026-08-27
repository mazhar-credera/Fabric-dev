CREATE   
	PROCEDURE dbo.usp_Update_DimAnalysisDimension
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimAnalysisDimension]'
	IF @@TRANCOUNT > 0 ROLLBACK; 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimAnalysisDimension]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimAnalysisDimension]')
	EXEC dbo.usp_Update_DimAnalysisDimension @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimAnalysisDimension ; 
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

			TRUNCATE TABLE dbo.DimAnalysisDimension ; 

			/*Insert unknown dimension record*/
			INSERT INTO dbo.DimAnalysisDimension ( 
				AnalysisDimensionSk, AnalysisDimensionBk, [Name] , CurrencyIsoCode, AnalysisLevel, HasAccount 
					,HasBusinessUnit, HasGrade, HasProduct, HasProposition, HasResource, HasResourceType, HasUser ,
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			SELECT 
				AnalysisDimensionSk, AnalysisDimensionBk, [Name] , CurrencyIsoCode, AnalysisLevel, HasAccount 
					,HasBusinessUnit, HasGrade, HasProduct, HasProposition, HasResource, HasResourceType, HasUser ,
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord' , 'ZZZ', 0, 0 , 
							0, 0, 0, 0, 0, 0, 0, 
								'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
									,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
								AnalysisDimensionSk, AnalysisDimensionBk, [Name] , CurrencyIsoCode, AnalysisLevel, HasAccount 
									,HasBusinessUnit, HasGrade, HasProduct, HasProposition, HasResource, HasResourceType, HasUser ,
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimAnalysisDimension B 
				WHERE	B.AnalysisDimensionSk = T.AnalysisDimensionSk 
			) ; 

			SELECT	 AnalysisDimensionBk		= T.Id 
					,[Name]
					,T.CurrencyIsoCode
					,AnalysisLevel			= T.KimbleOne__AnalysisLevel__c
					,HasAccount				= T.KimbleOne__HasAccount__c
					,HasBusinessUnit		= T.KimbleOne__HasBusinessUnit__c
					,HasGrade				= T.KimbleOne__HasGrade__c
					,HasProduct				= T.KimbleOne__HasProduct__c
					,HasProposition			= T.KimbleOne__HasProposition__c
					,HasResource			= T.KimbleOne__HasResource__c
					,HasResourceType		= T.KimbleOne__HasResourceType__c
					,HasUser				= T.KimbleOne__HasUser__c
					,_crda_ActiveFromDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) 
					,_crda_ActiveToDateTime		= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime)
					,AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_AnalysisDimension T 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
						  T.[Name]	
						, T.CurrencyIsoCode	 
						, T.KimbleOne__AnalysisLevel__c		
						, T.KimbleOne__HasAccount__c	
						, T.KimbleOne__HasBusinessUnit__c	
						, T.KimbleOne__HasGrade__c	
						, T.KimbleOne__HasProduct__c		
						, T.KimbleOne__HasProposition__c	
						, T.KimbleOne__HasResource__c	
						, T.KimbleOne__HasResourceType__c		
						, T.KimbleOne__HasUser__c 
						) 
					) AS VARBINARY(16)) AS _crda_Hash 
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 

			--SELECT [Before] = COUNT(1) FROM #Source 

			--Realign History dates
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'AnalysisDimension';

			--SELECT [After] = COUNT(1) FROM #Source 

		
			INSERT INTO dbo.DimAnalysisDimension(
				 AnalysisDimensionSk
				,AnalysisDimensionBk
				,[Name]
				,CurrencyIsoCode
				,AnalysisLevel
				,HasAccount
				,HasBusinessUnit
				,HasGrade
				,HasProduct
				,HasProposition
				,HasResource
				,HasResourceType
				,HasUser
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
				 RN= ROW_NUMBER()OVER (PARTITION BY SRC.AnalysisDimensionBk ORDER BY SRC._crda_ActiveFromDateTime)
				,SRC.AnalysisDimensionBk
				,SRC.[Name]
				,SRC.CurrencyIsoCode
				,SRC.AnalysisLevel
				,SRC.HasAccount
				,SRC.HasBusinessUnit
				,SRC.HasGrade
				,SRC.HasProduct
				,SRC.HasProposition
				,SRC.HasResource
				,SRC.HasResourceType
				,SRC.HasUser
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

			--SELECT [Dimension] = COUNT(1) FROM dbo.DimAnalysisDimension 


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