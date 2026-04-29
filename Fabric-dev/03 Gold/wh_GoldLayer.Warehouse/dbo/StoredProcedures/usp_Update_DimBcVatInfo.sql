CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_DimBcVatInfo
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBcVatInfo]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBcVatInfo]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBcVatInfo]')
	EXEC dbo.usp_Update_DimBcVatInfo @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimBcVatInfo ; 
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

			TRUNCATE TABLE dbo.DimBankAccount ; 

			INSERT INTO dbo.DimBcVatInfo ( 
				BcVatInfoSk, VatBusPostingGroup, VatProdPostingGroup 
						,_crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			SELECT	BcVatInfoSk, VatBusPostingGroup, VatProdPostingGroup 
							,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord', 'UnknownRecord' 
								, @_ExecutionId, GETUTCDATE()   ) 
					)	AS T(	BcVatInfoSk, VatBusPostingGroup, VatProdPostingGroup 
										,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimBcVatInfo B 
				WHERE	B.BcVatInfoSk = T.BcVatInfoSk 
			) ; 


			SELECT 
				  VatBusPostingGroup	= T.VAT_Bus_Posting_Group 
				, VatProdPostingGroup	= T.VAT_Prod_Posting_Group 
				, SystemModifiedAt		= MAX(T.[SystemModifiedAt])
			INTO #Source 
			FROM lh_SilverLayer.BC.HISTORY_GLEntry	T
			GROUP BY 
				  T.VAT_Bus_Posting_Group
				, T.VAT_Prod_Posting_Group ; 


			INSERT INTO	dbo.DimBcVatInfo 
			(
				 BcVatInfoSk 
				,VatBusPostingGroup 
				,VatProdPostingGroup 
				,_crda_CreatedExecutionId 
				,_crda_CreatedDateTime 
			) 
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY T.VatBusPostingGroup, T.VatProdPostingGroup)
				,T.VatBusPostingGroup 
				,T.VatProdPostingGroup	
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM #Source	T  
			ORDER BY T.VatBusPostingGroup, T.VatProdPostingGroup ; 

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S.SystemModifiedAt), @_Watermark),121) FROM #Source S ;

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