CREATE   
	PROCEDURE dbo.usp_Update_FactResourceBenchDates
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT  
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	/*Groundhogday Load*/

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceBenchDates]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceBenchDates]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceBenchDates]')
	EXEC dbo.usp_Update_FactResourceBenchDates @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactResourceBenchDates ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME = CAST(@Watermark AS DATETIME2) ,
			@_ProcessId		INT = @ProcessId;

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121) , 
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	DECLARE @TimeNow	DATETIME2= GETUTCDATE() ;
	DECLARE	@PastDate	DATE ; 
	DECLARE	@FutureDate	DATE ; 

	SELECT	@PastDate	= PastDate ,
			@FutureDate	= FutureDate
	FROM	dbo.FN_GetPastAndFutureDates (-3, 2);

	BEGIN TRY

		BEGIN TRANSACTION 

			TRUNCATE TABLE dbo.FactResourceBenchDates ;

			INSERT INTO dbo.FactResourceBenchDates 
			(
				 ResourceSk 
				,BenchStartDate 
				,BenchEndDate 
				,BenchStartDateSk	
				,BenchEndDateSk		

				,NumberOfDays
				,UtilisationPercentage
				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT
				 ResourceSk		= ISNULL(D.ResourceSk , -1)
				,I.BenchStartDate 
				,I.BenchEndDate	
				,(CONVERT([int],CONVERT([varchar](8),BenchStartDate,(112))))
				,(CONVERT([int],CONVERT([varchar](8),BenchEndDate,(112)))) 

				,I.NumberOfDays	
				,I.UtilisationPercentage 
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM	Internal.ResourceBenchDates I 
			LEFT JOIN dbo.DimResource			D	ON	D.ResourceBk	= I.ResourceBk 
													AND	D.IsCurrent		= 1

			--WHERE ISNULL(I.UtilisationPercentage,0) = 0
			ORDER BY ISNULL(D.ResourceSk , -1), I.BenchStartDate; 

			;WITH cteDuplicates
			AS(	/*PK/Unique constraints are not enforced so...*/ 
				SELECT	ResourceSk, BenchStartDate , 
						RN = ROW_NUMBER()
								OVER(
									PARTITION BY ResourceSk, BenchStartDate 
									ORDER BY	ResourceSk, BenchStartDate
								)
				FROM	dbo.FactResourceBenchDates T
			)
			DELETE	FROM cteDuplicates	
			WHERE	RN > 1 ; 

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(@TimeNow), @_Watermark),121) ;
			SELECT @strOldWatermark	= CONVERT(VARCHAR(35),@_Watermark,121);

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