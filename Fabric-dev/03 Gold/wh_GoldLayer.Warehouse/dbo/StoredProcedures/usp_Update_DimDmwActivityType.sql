CREATE  
	PROCEDURE dbo.usp_Update_DimDmwActivityType
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	SCD1 (Groundhog day) 

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDmwActivityType]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDmwActivityType]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDmwActivityType]')
	EXEC dbo.usp_Update_DimDmwActivityType @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimDmwActivityType ; 
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

			TRUNCATE TABLE dbo.DimDmwActivityType ; 

			INSERT INTO dbo.DimDmwActivityType ( 
				DmwActivityTypeSk, DmwActivityType
						,_crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			SELECT	DmwActivityTypeSk, DmwActivityType 
						,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' 
								, @_ExecutionId, GETUTCDATE()   ) 
					)	AS T(	DmwActivityTypeSk, DmwActivityType 
										,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimDmwActivityType B 
				WHERE	B.DmwActivityTypeSk = T.DmwActivityTypeSk 
			) ; 


		SELECT	DmwActivityType = R.KC_DMW_Activity_Type__c 
		INTO #Source 
		FROM		lh_SilverLayer.Kantata.HISTORY_ResourcedActivity R 
		GROUP BY R.KC_DMW_Activity_Type__c 
		ORDER BY R.KC_DMW_Activity_Type__c ; 


		INSERT INTO	dbo.DimDmwActivityType  
		(
			 DmwActivityTypeSk
			,DmwActivityType 
			,_crda_CreatedExecutionId
			,_crda_CreatedDateTime
		)
		SELECT
			 ROW_NUMBER()OVER (ORDER BY SRC.DmwActivityType)
			,SRC.DmwActivityType 
			,@_ExecutionId 
			,GETUTCDATE() 
		FROM	#Source SRC  


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