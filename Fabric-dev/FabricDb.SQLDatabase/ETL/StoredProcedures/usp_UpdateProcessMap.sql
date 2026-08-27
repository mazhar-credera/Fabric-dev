CREATE   
	PROCEDURE ETL.usp_UpdateProcessMap
		@ProcessId			INT , 
		@ExecutionId		INT			= NULL, 
		@UpdateType			VARCHAR(20) , /*'ExecutionId', 'BronzeWatermark', 'SilverWatermark', 'RunStatus' */ 
		@NewWatermark		VARCHAR(255)= NULL , 
		@NewRunStatus		VARCHAR(10) = NULL 

AS
BEGIN 
SET NOCOUNT ON ;
	DECLARE
		@_ProcessId			INT			= @ProcessId ,
		@_ExecutionId		INT			= @ExecutionId ,
		@_UpdateType		VARCHAR(255)= @UpdateType ,
		@_NewWatermark		VARCHAR(255)= @NewWatermark ,
		@_NewRunStatus		VARCHAR(10)	= @NewRunStatus ;

	IF @_UpdateType = 'ExecutionId'
	BEGIN
		UPDATE	P
		SET		LastExecutionId	= @_ExecutionId
		FROM	ETL.ProcessMap	P
		WHERE	P.ProcessId = @_ProcessId;
	END ;

	IF @_UpdateType = 'BronzeWatermark'
	BEGIN
		UPDATE	P
		SET		P.BronzeWatermarkValue = CONVERT(VARCHAR(35),@_NewWatermark, 121)
		FROM	ETL.ProcessMap P
		WHERE	P.ProcessId = @_ProcessId
	END ;

	IF @_UpdateType = 'SilverWatermark'
	BEGIN
		UPDATE	P
		SET		P.SilverWatermarkValue = CONVERT(VARCHAR(35),@_NewWatermark, 121)
		FROM	ETL.ProcessMap P
		WHERE	P.ProcessId = @_ProcessId
	END ;

	IF @_UpdateType = 'CurrentWatermark'
	BEGIN
		UPDATE	P
		SET		P.CurrentWatermark = CONVERT(VARCHAR(35),@_NewWatermark, 121)
		FROM	ETL.ProcessMap P
		WHERE	P.ProcessId = @_ProcessId
	END ;

	IF @_UpdateType = 'RunStatus'
	BEGIN
		UPDATE	P
		SET		P.RunStatus = @_NewRunStatus 
		FROM	ETL.ProcessMap P
		WHERE	P.ProcessId = @_ProcessId
	END ;

	--return something for the Fabric Lookup
	SELECT RetVal = 1;

END ;

GO

