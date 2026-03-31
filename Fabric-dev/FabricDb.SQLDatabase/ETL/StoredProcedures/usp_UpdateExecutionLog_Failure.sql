CREATE   
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
		@_ProcessId 		INT				= @ProcessId , 
		@FinalStatus		VARCHAR(50)		= 'Error' ;


	--to swallow return dataset from Meta.usp_UpdateProcessMap
	DECLARE @ProcessMap TABLE (RetVal BIT NULL ) ; 

	UPDATE	b
	SET		ExecutionEndTime = GETUTCDATE() , 
			FinalStatus		 = @FinalStatus , 
			ErrorDetail		 = @_ErrorMessage 
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
		@NewRunStatus	= @FinalStatus ;

	--return something for the Fabric Lookup
	SELECT RetVal = 1;

END ;

GO

