CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_CandidateResource
	--Default Parameters
	@ExecutionId	INT ,
	@Watermark		VARCHAR(255) ,
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	SCD1 (Groundhog day) pseudo Dimension
	Truncated and reloaded

	USAGE
	SELECT * FROM Meta.ProcessMap WHERE ProcessPath LIKE '%usp_Update_CandidateResource%'
	EXEC dbo.usp_Update_CandidateResource @ExecutionId = -1, @Watermark ='20000101', @ProcessId=99; 
	SELECT * FROM dbo.CandidateResource ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			TRUNCATE TABLE dbo.CandidateResource;
		
			INSERT INTO dbo.CandidateResource
			(
				CandidateResourceBk ,
				[Name] , 
				FirstName , 
				LastName , 
				CandidateNotSetUp , 
				_crda_CreatedExecutionId , 
				_crda_CreatedDateTime
			)
			SELECT	CandidateResourceBk = CR.Id , 
					[Name]			= IIF(CHARINDEX('(', CR.[Name]) = 0, CR.[Name], LEFT(CR.[Name], CHARINDEX('(', CR.[Name]) - 1)) ,
					FirstName		= ISNULL(CR.KimbleOne__FirstName__c , '') , 
					LastName		= IIF(CHARINDEX('(', CR.KimbleOne__LastName__c) = 0, 
										CR.KimbleOne__LastName__c, 
											LEFT(CR.KimbleOne__LastName__c, CHARINDEX('(', CR.KimbleOne__LastName__c) - 1)) ,
					CandidateNotSetUp	= IIF(CR.KimbleOne__Resource__c IS NULL, 1, 0 ) , 
					@_ExecutionId , 
					GETUTCDATE() 
			FROM	lh_SilverLayer.Kantata.HISTORY_CandidateResource CR
			WHERE	CR._crda_IsActive = 1 
			AND		CR._crda_ActiveToDateTime = '90001231'
			ORDER BY [Name] ; 

		SELECT @strNewWatermark	, 
				@strOldWatermark ; 

		COMMIT;

	END TRY
	BEGIN CATCH
	  ROLLBACK;
	  THROW;
	END CATCH ; 

	IF @@TRANCOUNT > 0 ROLLBACK; 

END;