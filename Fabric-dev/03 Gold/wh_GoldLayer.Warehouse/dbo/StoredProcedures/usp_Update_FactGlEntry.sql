CREATE   
	PROCEDURE dbo.usp_Update_FactGlEntry
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactGlEntry]';
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactGlEntry]');
	DECLARE @LastExecId INT = (SELECT MAX(LastExecutionId) FROM FabricDb.ETL.ProcessMap);
	EXEC dbo.usp_Update_FactGlEntry @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactGlEntry ; 
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

			TRUNCATE TABLE dbo.FactGlEntry ; 


			SELECT
				 GlEntrySk			= ISNULL(DG.GlEntrySk, -1) 
				,BcCompanySk		= ISNULL(BC.BcCompanySk , -1) 

				,GLAccountSk		= ISNULL(GA.GLAccountSk , -1) 
				,GlBalAccountSk		= ISNULL(BA.GlBalAccountSk, -1) 
				,GlDimensionCodeSk	= ISNULL(DC.GlDimensionCodeSk, -1) 
				,BcVatInfoSk		= ISNULL(DV.BcVatInfoSk, -1) 

				,PostingDate		= IIF(GL.Posting_Date < '19000201', NULL, CAST(GL.Posting_Date AS DATE) ) 
				,DocumentDate		= IIF(GL.Document_Date < '19000201', NULL, CAST(GL.Document_Date AS DATE) ) 

				,GL.Amount 
				,CreditAmount		= GL.Credit_Amount 
				,DebitAmount		= GL.Debit_Amount 
				,VATAmount			= GL.VAT_Amount 

				,SystemModifiedAt 
				,RN = ROW_NUMBER()OVER (ORDER BY ISNULL(DG.GlEntrySk, -1), ISNULL(BC.BcCompanySk , -1), GL.SystemModifiedAt) 

			INTO #Source 
			FROM	lh_SilverLayer.BC.HISTORY_GLEntry			GL 

			LEFT JOIN	dbo.DimBcCompany	BC	ON	BC.BC_CompanyName = GL.BC_CompanyName 

			LEFT JOIN	dbo.DimGlEntry		DG	ON	DG.GlEntryNo	= GL.Entry_No 
												AND	DG.BcCompanySk	= BC.BcCompanySk 

			LEFT JOIN	dbo.DimGLAccount	GA	ON	GA.[No]			= GL.G_L_Account_No 
												AND	GA.BcCompanySk	= BC.BcCompanySk 

			LEFT JOIN	dbo.DimGlDimensionCode	DC	ON	DC.GlobalDimension1Code	= GL.Global_Dimension_1_Code 
													AND	DC.GlobalDimension2Code	= GL.Global_Dimension_2_Code 

			LEFT JOIN	dbo.DimGlBalAccount	BA	ON	BA.BalAccountNo		= GL.Bal_Account_No 
												AND	BA.BalAccountType	= GL.Bal_Account_Type 

			LEFT JOIN	dbo.DimBcVatInfo	DV	ON	DV.VatBusPostingGroup	= GL.VAT_Bus_Posting_Group 
												AND	DV.VatProdPostingGroup	= GL.VAT_Prod_Posting_Group  

			WHERE	GL._crda_isDeleted			= 0  
			AND		GL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			AND		GL._crda_ActiveFromDateTime >= @_Watermark ; 


			INSERT INTO	dbo.FactGlEntry  
			( 
				 GlEntrySk
				, BcCompanySk 
				, GLAccountSk	 
				, GlBalAccountSk	
				, GlDimensionCodeSk 
				, BcVatInfoSk

				, PostingDate	
				, DocumentDate 

				, Amount	
				, CreditAmount
				, DebitAmount 
				, VATAmount

				, _crda_CreatedExecutionId 
				, _crda_CreatedDateTime 
			)
			SELECT
				  SRC.GlEntrySk
				, SRC.BcCompanySk 
				, SRC.GLAccountSk	 
				, SRC.GlBalAccountSk	
				, SRC.GlDimensionCodeSk 
				, SRC.BcVatInfoSk

				, SRC.PostingDate	
				, SRC.DocumentDate 

				, SRC.Amount 
				, SRC.CreditAmount 
				, SRC.DebitAmount 
				, SRC.VATAmount 

				, @_ExecutionId 
				, GETUTCDATE() 

			FROM	#Source SRC 
			WHERE	RN = 1 
			ORDER BY SRC.GlEntrySk, SRC.BcCompanySk ; 


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