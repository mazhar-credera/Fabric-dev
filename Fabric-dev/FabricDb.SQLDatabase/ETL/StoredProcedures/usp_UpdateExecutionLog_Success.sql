CREATE   
	PROCEDURE ETL.usp_UpdateExecutionLog_Success
		@ExecutionId		INT , 
		@Status				VARCHAR(50) ,  /* 'BronzeWatermark', 'SilverWatermark' */
		@InitialWatermark	VARCHAR(255) = NULL , 
		@UpdatedWatermark	VARCHAR(255) = NULL , 
		@ProcessId			INT = NULL 
AS
BEGIN 
SET NOCOUNT ON ;
	DECLARE
		@_ExecutionId		INT = @ExecutionId, 
		@_Status			VARCHAR(50)		= @Status,  /* 'BronzeWatermark', 'SilverWatermark' */
		@_InitialWatermark	VARCHAR(255)	= @InitialWatermark , 
		@_UpdatedWatermark	VARCHAR(255)	= @UpdatedWatermark , 
		@_ProcessId 		INT				= @ProcessId ; 

	--to swallow return dataset from Meta.usp_UpdateProcessMap
	DECLARE @ProcessMap TABLE (RetVal BIT NULL ) ; 

	UPDATE	b
	SET		ExecutionEndTime = GETUTCDATE() , 
			FinalStatus	= 'Done' , 
			InitialWatermark= CONVERT(VARCHAR(35),@_InitialWatermark, 121) , 
			UpdatedWatermark= CONVERT(VARCHAR(35),@_UpdatedWatermark, 121) 
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
		@UpdateType		= @_Status , 
		@NewWatermark	= @_UpdatedWatermark ;

	--return something for the Fabric Lookup
	SELECT Success = 1;

END ;

GO

