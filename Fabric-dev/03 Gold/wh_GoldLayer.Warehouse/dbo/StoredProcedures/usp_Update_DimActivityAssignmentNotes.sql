CREATE   
	PROCEDURE dbo.usp_Update_DimActivityAssignmentNotes
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimActivityAssignmentNotes]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimActivityAssignmentNotes]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimActivityAssignmentNotes]')
	EXEC dbo.usp_Update_DimActivityAssignmentNotes @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM dbo.DimActivityAssignmentNotes ; --7979 
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

			TRUNCATE TABLE dbo.DimActivityAssignmentNotes ; 
		
			/*Insert unknown dimension record*/
			INSERT INTO dbo.DimActivityAssignmentNotes ( 
				ActivityAssignmentNotesSk, ActivityAssignmentBk, ActivityAssignmentLogNotes
						, _crda_Hash, _crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			SELECT	ActivityAssignmentNotesSk, ActivityAssignmentBk, ActivityAssignmentLogNotes
						, _crda_Hash, _crda_CreatedExecutionId, _crda_CreatedDateTime
			FROM	(VALUES	(	
					-1 , 'UnknownRecord', 'UnknownRecordNotes'
							 ,0x00, @_ExecutionId, GETUTCDATE()  ) 
					)	AS T(	ActivityAssignmentNotesSk, ActivityAssignmentBk, ActivityAssignmentLogNotes
									, _crda_Hash, _crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimActivityAssignmentNotes B 
				WHERE	B.ActivityAssignmentNotesSk = T.ActivityAssignmentNotesSk 
			) ; 


			SELECT	 
				 ActivityAssignmentBk		= A.Id
				,ActivityAssignmentLogNotes	= A.KimbleOne__LongNotes__c 
				,A._crda_ActiveFromDateTime 
				,A._crda_ActiveToDateTime 
				,AD._crda_Hash 

			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment A

			CROSS APPLY (
			SELECT
			CAST(HASHBYTES('MD5',
				CONCAT_WS('||',	
						  ISNULL(A.KimbleOne__LongNotes__c ,'') 
						, ''  
					) 
				) AS VARBINARY(16)) AS _crda_Hash
			)  AD 
			WHERE	A.KimbleOne__LongNotes__c	IS NOT NULL 
			AND		A._crda_isDeleted			= 0  
			AND		A._crda_ActiveToDateTime	= '99991231 23:59:59'  ; 


			INSERT INTO	dbo.DimActivityAssignmentNotes 
			( 
				 ActivityAssignmentNotesSk 
				,ActivityAssignmentBk
				,ActivityAssignmentLogNotes

				,_crda_Hash 
				,_crda_CreatedExecutionId 
				,_crda_CreatedDateTime 
			)
			SELECT 
				 RN= ROW_NUMBER()OVER (PARTITION BY SRC.ActivityAssignmentBk ORDER BY SRC._crda_ActiveFromDateTime)
				,SRC.ActivityAssignmentBk 
				,SRC.ActivityAssignmentLogNotes 
				
				,_crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM #Source SRC ; 

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