CREATE   
	PROCEDURE ETL.usp_InsertExecutionLog
		@BatchId		INT , 
		@ProcessId		INT , 
		@ExternalHandlerId	VARCHAR(255) , 
		@PipelineName		VARCHAR(255) , 
		@LogDescription		VARCHAR(255) ,
		@WorkspaceId		VARCHAR(1024) 

AS
BEGIN 
SET NOCOUNT ON ;
	INSERT INTO ETL.ExecutionLog 
		( ProcessId, BatchId, LogDescription, PipelineName, ExternalHandlerId, WorkspaceId, FinalStatus)
	VALUES
		(@ProcessId, @BatchId, @LogDescription, @PipelineName, @ExternalHandlerId, @WorkspaceId, 'Start')

	SELECT ExecutionId=SCOPE_IDENTITY();

END ;

GO

