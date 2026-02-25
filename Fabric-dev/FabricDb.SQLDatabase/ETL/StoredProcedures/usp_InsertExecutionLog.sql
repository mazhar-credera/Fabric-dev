CREATE   
	PROCEDURE ETL.usp_InsertExecutionLog
		@BatchId		INT , 
		@ProcessId		INT , 
		@ExternalHandlerId	VARCHAR(255) , 
		@LogDescription		VARCHAR(255) , 
		@ExecutionId	INT OUTPUT

AS
BEGIN 
SET NOCOUNT ON ;
	INSERT INTO ETL.ExecutionLog 
		( ProcessId, BatchId, LogDescription, ExternalHandlerId, FinalStatus)
	VALUES
		(@ProcessId, @BatchId, @LogDescription, @ExternalHandlerId, 'Start')

	SELECT @ExecutionId=SCOPE_IDENTITY();

	SELECT ExecutionId = @ExecutionId;

END ;

GO

