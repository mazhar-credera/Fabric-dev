CREATE  
	PROCEDURE dbo.usp_Update_DimBankAccountLedgerEntry
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBankAccountLedgerEntry]';
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBankAccountLedgerEntry]');
	--DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBankAccountLedgerEntry]');
	DECLARE @LastExecId INT = (SELECT MAX(LastExecutionId) FROM FabricDb.ETL.ProcessMap);
	EXEC dbo.usp_Update_DimBankAccountLedgerEntry @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimBankAccountLedgerEntry ; 
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

			TRUNCATE TABLE dbo.DimBankAccountLedgerEntry ; 

			INSERT INTO dbo.DimBankAccountLedgerEntry ( 
				BankAccountLedgerEntrySk, BankAccountLedgerEntryNo, BcCompanySk, BankAccountSk, GlBalAccountSk, GlDimensionCodeSk, BcUserSk
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			SELECT 
				BankAccountLedgerEntrySk, BankAccountLedgerEntryNo, BcCompanySk, BankAccountSk, GlBalAccountSk, GlDimensionCodeSk, BcUserSk
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			FROM	(VALUES	(	
								-1 , -1, -1, -1, -1, -1, -1
									,0x00 , @_ExecutionId, GETUTCDATE()   ) 
					)	AS T(	
								BankAccountLedgerEntrySk, BankAccountLedgerEntryNo, BcCompanySk, BankAccountSk, GlBalAccountSk, GlDimensionCodeSk, BcUserSk
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimBankAccountLedgerEntry B 
				WHERE	B.BankAccountLedgerEntrySk = T.BankAccountLedgerEntrySk  
			) ; 


			SELECT
				 BankAccountLedgerEntryNo	= BL.EntryNo
				,BcCompanySk			= ISNULL(BC.BcCompanySk , -1) 

				,BankAccountSk		= ISNULL(BA.BankAccountSk , -1) 
				,GlBalAccountSk		= ISNULL(GB.GlBalAccountSk, -1)
				,GlDimensionCodeSk	= ISNULL(DC.GlDimensionCodeSk, -1) 
				,BcUserSk			= ISNULL(BU.BcUserSk, -1) 

				,InvoiceNo			= BL.DocumentNo 
				,BL.DocumentNo
				,BL.ExternalDocumentNo
				,BL.[Description]
				,BL.SourceCode

				,CurrencyCode		= IIF(BL.BankAccPostingGroup LIKE '%STERLING%', 'GBP', BL.CurrencyCode) 
				,BankAccPostingGroup 

				,BL.DimensionSetID
				,BL.DocumentType
				,BL.JournalBatchName
				,BL.ReasonCode 

				,BL.ClosedbyEntryNo
				,BL.[Open] 
				,BL.Positive
				,BL.Reversed
				,BL.ReversedbyEntryNo
				,BL.ReversedEntryNo

				,BL.StatementLineNo
				,BL.StatementNo
				,BL.StatementStatus
				,BL.TransactionNo

				,BL._crda_ActiveFromDateTime 
				,AD._crda_Hash 

			INTO #Source 
			FROM lh_SilverLayer.BC.HISTORY_BankAccountLedgerEntry	BL 

			LEFT JOIN	dbo.DimBcCompany	BC	ON	BC.BC_CompanyName = BL.BC_CompanyName 

			LEFT JOIN	dbo.DimBankAccount	BA	ON	BA.BcCompanySk	 = BC.BcCompanySk 
												AND	BA.[No]			 = BL.BankAccountNo

			LEFT JOIN	dbo.DimGlDimensionCode	DC	ON	DC.GlobalDimension1Code	= BL.GlobalDimension1Code 
													AND	DC.GlobalDimension2Code	= BL.GlobalDimension2Code 

			LEFT JOIN	dbo.DimGlBalAccount	GB	ON	GB.BalAccountNo		= BL.BalAccountNo 
												AND	GB.BalAccountType	= BL.BalAccountType  

			LEFT JOIN	dbo.DimBcUser		BU	ON	BU.BcUserID = BL.UserID 

			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								 ISNULL(BA.BankAccountSk , -1) 
								,ISNULL(GB.GlBalAccountSk, -1)
								,ISNULL(DC.GlDimensionCodeSk, -1)
								,ISNULL(BU.BcUserSk, -1) 

								,BL.ExternalDocumentNo
								,BL.[Description]
								,BL.SourceCode

								,IIF(BL.BankAccPostingGroup LIKE '%STERLING%', 'GBP', BL.CurrencyCode) 
								,BankAccPostingGroup 

								,BL.DimensionSetID
								,BL.DocumentType
								,BL.JournalBatchName
								,BL.ReasonCode 

								,BL.ClosedbyEntryNo
								,BL.[Open] 
								,BL.Positive
								,BL.Reversed
								,BL.ReversedbyEntryNo
								,BL.ReversedEntryNo

								,BL.StatementLineNo
								,BL.StatementNo
								,BL.StatementStatus
								,BL.TransactionNo
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	BL.PostingDate >= '2017-03-31' 
			AND		BL._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			AND		BL._crda_isDeleted = 0 
			AND		BL._crda_ActiveFromDateTime >= @_Watermark ; 



			INSERT INTO	dbo.DimBankAccountLedgerEntry 
			(
				 BankAccountLedgerEntrySk 
				,BankAccountLedgerEntryNo
				,BcCompanySk
				,BankAccountSk
				,GlBalAccountSk
				,GlDimensionCodeSk
				,BcUserSk
				,InvoiceNo
				,DocumentNo
				,ExternalDocumentNo
				,[Description]
				,SourceCode
				,CurrencyCode
				,BankAccPostingGroup
				,DimensionSetID
				,DocumentType
				,JournalBatchName
				,ReasonCode
				,ClosedbyEntryNo
				,[Open]
				,Positive
				,Reversed
				,ReversedbyEntryNo
				,StatementLineNo
				,StatementNo
				,StatementStatus
				,TransactionNo

				, _crda_Hash 
				, _crda_CreatedExecutionId 
				, _crda_CreatedDateTime 
			)
			SELECT
				 ROW_NUMBER()OVER (ORDER BY BankAccountLedgerEntryNo, BcCompanySk, SRC._crda_ActiveFromDateTime)
				, SRC.BankAccountLedgerEntryNo
				, SRC.BcCompanySk
				, SRC.BankAccountSk
				, SRC.GlBalAccountSk
				, SRC.GlDimensionCodeSk
				, SRC.BcUserSk
				, SRC.InvoiceNo
				, SRC.DocumentNo
				, SRC.ExternalDocumentNo
				, SRC.[Description]
				, SRC.SourceCode
				, SRC.CurrencyCode
				, SRC.BankAccPostingGroup
				, SRC.DimensionSetID
				, SRC.DocumentType
				, SRC.JournalBatchName
				, SRC.ReasonCode
				, SRC.ClosedbyEntryNo
				, SRC.[Open]
				, SRC.Positive
				, SRC.Reversed
				, SRC.ReversedbyEntryNo
				, SRC.StatementLineNo
				, SRC.StatementNo
				, SRC.StatementStatus
				, SRC.TransactionNo

				, SRC._crda_Hash 
				, @_ExecutionId 
				, GETUTCDATE() 
			FROM	#Source SRC 
			ORDER BY BankAccountLedgerEntryNo, BcCompanySk, SRC._crda_ActiveFromDateTime ;


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