CREATE  
	PROCEDURE dbo.usp_Update_DimResourcedActivityName
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResourcedActivityName]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResourcedActivityName]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResourcedActivityName]')
	EXEC dbo.usp_Update_DimResourcedActivityName @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimResourcedActivityName ; 
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

			TRUNCATE TABLE dbo.DimResourcedActivityName ; 

			INSERT INTO dbo.DimResourcedActivityName ( 
				ResourcedActivityNameSk, ResourcedActivityName
						,_crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			SELECT	ResourcedActivityNameSk, ResourcedActivityName 
						,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' 
								, @_ExecutionId, GETUTCDATE() ) 
					)	AS T(	ResourcedActivityNameSk, ResourcedActivityName 
										,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimResourcedActivityName B 
				WHERE	B.ResourcedActivityNameSk = T.ResourcedActivityNameSk 
			) ; 



			SELECT	ResourcedActivityName = R.DisplayName__c , 
					_crda_ActiveFromDateTime= MAX(CONVERT(DATETIME2(6), R._crda_ActiveFromDateTime))
			INTO #Source  
			FROM	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity R 
			WHERE	R._crda_isDeleted		= 0  
			AND		R._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
			GROUP BY R.DisplayName__c 
			ORDER BY R.DisplayName__c ; 


			INSERT INTO	dbo.DimResourcedActivityName  
			( 
				 ResourcedActivityNameSk
				,ResourcedActivityName 
				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT
				 ROW_NUMBER()OVER (ORDER BY SRC.ResourcedActivityName) 
				,SRC.ResourcedActivityName 
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM	#Source SRC ; 

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