CREATE --OR ALTER 
	PROCEDURE ETL.usp_UpdateExecutionLog_Failure
		@ExecutionId		INT , 
		@ErrorMessage		VARCHAR(MAX)  , 
		@ProcessId			INT = NULL 
AS
BEGIN 
SET NOCOUNT ON ;
	DECLARE
		@_ExecutionId		INT = @ExecutionId, 
		@_ErrorMessage		VARCHAR(MAX)	= @ErrorMessage , 
		@_ProcessId 		INT				= @ProcessId ; 

	--to swallow return dataset from Meta.usp_UpdateProcessMap
	DECLARE @ProcessMap TABLE (RetVal BIT NULL ) ; 

	UPDATE	b
	SET		ExecutionEndTime = GETUTCDATE() , 
			FinalStatus	= 'Error' , 
			ErrorDetail	= @_ErrorMessage 
	FROM	ETL.ExecutionLog	b
	WHERE	b.ExecutionId = @_ExecutionId;
		
	INSERT INTO @ProcessMap(RetVal)
	EXEC ETL.usp_UpdateProcessMap
		@ProcessId		= @_ProcessId , 
		@UpdateType		= 'ExecutionId' , 
		@ExecutionId	= @_ExecutionId ;

	INSERT INTO @ProcessMap(RetVal)
	EXEC ETL.usp_UpdateProcessMap
		@ProcessId		= @_ProcessId , 
		@UpdateType		= 'RunStatus' ,
		@NewRunStatus	= 'Error' ;

	--return something for the Fabric Lookup
	SELECT Success = 1;

END ;

GO

