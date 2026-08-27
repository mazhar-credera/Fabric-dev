CREATE  
	PROCEDURE dbo.usp_Update_DimInvoiceStatus
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimInvoiceStatus]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimInvoiceStatus]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimInvoiceStatus]')
	EXEC dbo.usp_Update_DimInvoiceStatus @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimInvoiceStatus ; 
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

			TRUNCATE TABLE dbo.DimInvoiceStatus ; 

			INSERT INTO dbo.DimInvoiceStatus ( 
				InvoiceStatusSk, InvoiceStatusBk, InvoiceStatus, InvoiceDomain
						,_crda_Hash ,_crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			SELECT	InvoiceStatusSk, InvoiceStatusBk, InvoiceStatus , InvoiceDomain
						,_crda_Hash ,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord', 'UnknownRecord', -1
								, 0x00, @_ExecutionId, GETUTCDATE()   ) 
					)	AS T(	InvoiceStatusSk, InvoiceStatusBk, InvoiceStatus , InvoiceDomain
										,_crda_Hash ,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimInvoiceStatus B 
				WHERE	B.InvoiceStatusSk = T.InvoiceStatusSk 
			) ; 


			SELECT  
				 InvoiceStatusBk	= KI.KimbleOne__Status__c
				,InvoiceStatus		= RD.[Name] 
				,InvoiceDomain		= RD.KimbleOne__Domain__c 
				,_crda_ActiveFromDateTime	= MAX(CONVERT(DATETIME2(6), KI._crda_ActiveFromDateTime) )
				,AD._crda_Hash 

			INTO #Source
			FROM		lh_SilverLayer.Kantata.HISTORY_Invoice			KI	

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ReferenceData	RD	ON	RD.Id				= KI.KimbleOne__Status__c
																			AND RD._crda_isDeleted	= 0 
																			AND	RD._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  RD.[Name] 
								, RD.KimbleOne__Domain__c 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	KI._crda_isDeleted = 0 
			GROUP BY 
				 KI.KimbleOne__Status__c
				,RD.[Name] 
				,RD.KimbleOne__Domain__c 
				,AD._crda_Hash ; 


			INSERT INTO	dbo.DimInvoiceStatus  
			(
				 InvoiceStatusSk 
				,InvoiceStatusBk 
				,InvoiceStatus 
				,InvoiceDomain 

				,_crda_Hash 
				,_crda_CreatedExecutionId 
				,_crda_CreatedDateTime 
			)
			SELECT
				 ROW_NUMBER()OVER (ORDER BY SRC.InvoiceStatusBk, SRC._crda_ActiveFromDateTime) 
				,SRC.InvoiceStatusBk 
				,SRC.InvoiceStatus 
				,SRC.InvoiceDomain 

				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM	#Source SRC 
			ORDER BY SRC.InvoiceStatusBk, SRC._crda_ActiveFromDateTime ; 


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