CREATE   
	PROCEDURE dbo.usp_Update_DimResourcedActivityType
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResourcedActivityType]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResourcedActivityType]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResourcedActivityType]')
	EXEC dbo.usp_Update_DimResourcedActivityType @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId 
	SELECT * FROM [dbo].[DimResourcedActivityType] ORDER BY ResourcedActivityTypeSk; 
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

			TRUNCATE TABLE dbo.DimResourcedActivityType ; 

			INSERT INTO dbo.DimResourcedActivityType ( 
				ResourcedActivityTypeSk, ResourcedActivityTypeBk, [Name],
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT 	ResourcedActivityTypeSk, ResourcedActivityTypeBk, [Name], 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' ,
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	ResourcedActivityTypeSk, ResourcedActivityTypeBk, [Name], 
								_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
									,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimResourcedActivityType B 
				WHERE	B.ResourcedActivityTypeSk = T.ResourcedActivityTypeSk 
			) ; 



			SELECT	ResourcedActivityTypeBk			= T.Id , 
					T.[Name], 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_ResourcedActivityType		T 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.[Name]	
								, CAST(''  AS VARCHAR(80))
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 



			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'ResourcedActivityType';

			INSERT INTO dbo.DimResourcedActivityType
			( 
				ResourcedActivityTypeSk , 
				ResourcedActivityTypeBk , 
				[Name] 

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
				ROW_NUMBER()OVER (ORDER BY SRC.ResourcedActivityTypeBk, SRC._crda_ActiveFromDateTime) , 
				SRC.ResourcedActivityTypeBk , 
				SRC.[Name] 

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
			ORDER BY SRC.ResourcedActivityTypeBk, SRC._crda_ActiveFromDateTime ; 


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