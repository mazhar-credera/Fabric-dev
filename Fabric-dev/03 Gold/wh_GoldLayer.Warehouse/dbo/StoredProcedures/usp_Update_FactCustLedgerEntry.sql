CREATE  
	PROCEDURE dbo.usp_Update_FactCustLedgerEntry
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactCustLedgerEntry]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactCustLedgerEntry]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactCustLedgerEntry]')
	EXEC dbo.usp_Update_FactCustLedgerEntry @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM dbo.FactCustLedgerEntry ; 
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

			TRUNCATE TABLE dbo.FactCustLedgerEntry ; 

			DROP TABLE IF EXISTS #Src ;

			SELECT	
				 DCE.CustLedgerEntrySk
				,BcCompanySk			= ISNULL(BC.BcCompanySk, -1) 
				,RN	= ROW_NUMBER()OVER
						(
							PARTITION BY	CL.EntryNo,ISNULL(DCL.EntryNo , -1),ISNULL(BC.BcCompanySk, -1) 
							ORDER BY		CL._crda_ActiveFromDateTime 
						)
				,CustomerSk				= ISNULL(DC.CustomerSk, -1) 
				,GlBalAccountSk			= ISNULL(GB.GlBalAccountSk, -1) 
				,LedgerEntryUserSk			= ISNULL(BCC.BcUserSk, -1)
				,DetailedLedgerEntryUserSk	= ISNULL(BCD.BcUserSk, -1)

				,ClosedatDate			= CAST(CL.ClosedatDate AS DATE) 
				,DocumentDate			= CAST(CL.DocumentDate AS DATE) 
				,DueDate				= CAST(CL.DueDate AS DATE) 
				,PostingDate			= CAST(CL.PostingDate AS DATE) 
				,InvoiceDate			= CAST(CL.DocumentDate AS DATE) 
				,InitialEntryDueDate	= CAST(DCL.InitialEntryDueDate AS DATE) 
				,OriginalDueDate		= CAST(CL.OriginalDueDate AS DATE) 

				,CurrencyCode			= IIF(CL.CurrencyCode = '', 'GBP', CL.CurrencyCode) 
				,DCL.Amount 
				,AmountLCYExcVAT		= CL.SalesLCY 
				,AmountLCYIncVAT		= DCL.AmountLCY	
				,DCL.CreditAmount 
				,DCL.CreditAmountLCY 
				,DCL.DebitAmount 
				,DCL.DebitAmountLCY 
				,DCL.LedgerEntryAmount 
				,CL._crda_ActiveFromDateTime 

			INTO #Src 
			FROM		lh_SilverLayer.BC.HISTORY_CustLedgerEntry			CL
			LEFT JOIN	lh_SilverLayer.BC.HISTORY_DetailedCustLedgEntry	DCL	ON	DCL.CustLedgerEntryNo	= CL.EntryNo 
																AND DCL.BC_CompanyName		= CL.BC_CompanyName
																AND	DCL._crda_isDeleted		= 0  
																AND	DCL._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	dbo.DimBcCompany					BC	ON	BC.BC_CompanyName		= CL.BC_CompanyName 

			LEFT JOIN	dbo.DimCustLedgerEntry				DCE	ON	DCE.CustLedgerEntryNo	= CL.EntryNo
																AND	DCE.DetailedLedgerEntryNo= DCL.EntryNo
																AND	DCE.BcCompanySk			= BC.BcCompanySk 

			LEFT JOIN	dbo.DimCustomer						DC	ON	DC.[No]			= CL.CustomerNo 
																AND DC.BcCompanySk	= BC.BcCompanySk 

			LEFT JOIN	dbo.DimGlBalAccount					GB	ON	GB.BalAccountNo		= CL.BalAccountNo 
																AND	GB.BalAccountType	= CL.BalAccountType 

			LEFT JOIN	dbo.DimBcUser						BCC	ON	BCC.BcUserId	= CL.UserID 

			LEFT JOIN	dbo.DimBcUser						BCD	ON	BCD.BcUserId	= DCL.UserID


			WHERE	CL._crda_isDeleted			= 0  
			AND		CL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			AND		CL._crda_ActiveFromDateTime >= @_Watermark ; 
			/*SELECT COUNT(1) FROM #Src*/

	/*		DELETE FROM #Src 
			WHERE	RN> 1 ;
	*/



			INSERT INTO	dbo.FactCustLedgerEntry  
			( 
				 CustLedgerEntrySk
				,BcCompanySk

				,CustomerSk
				,GlBalAccountSk
				,LedgerEntryUserSk
				,DetailedLedgerEntryUserSk

				,ClosedatDate
				,DocumentDate
				,DueDate
				,InitialEntryDueDate
				,InvoiceDate
				,OriginalDueDate
				,PostingDate

				,ClosedatDateSk			
				,DocumentDateSk			
				,DueDateSk				
				,InitialEntryDueDateSk	
				,InvoiceDateSk			
				,OriginalDueDateSk		
				,PostingDateSk	

				,CurrencyCode
				,Amount
				,AmountLCYExcVAT
				,AmountLCYIncVAT
				,CreditAmount
				,CreditAmountLCY
				,DebitAmount
				,DebitAmountLCY
				,LedgerEntryAmount

				, _crda_CreatedExecutionId 
				, _crda_CreatedDateTime 
			)
			SELECT 
				 SRC.CustLedgerEntrySk
				, SRC.BcCompanySk

				, SRC.CustomerSk
				, SRC.GlBalAccountSk
				, SRC.LedgerEntryUserSk
				, SRC.DetailedLedgerEntryUserSk

				, SRC.ClosedatDate
				, SRC.DocumentDate
				, SRC.DueDate
				, SRC.InitialEntryDueDate
				, SRC.InvoiceDate
				, SRC.OriginalDueDate
				, SRC.PostingDate

				,(CONVERT([int],CONVERT([varchar](8),ClosedatDate,(112))))  
				,(CONVERT([int],CONVERT([varchar](8),DocumentDate,(112))))  
				,(CONVERT([int],CONVERT([varchar](8),DueDate,(112))))  
				,(CONVERT([int],CONVERT([varchar](8),InitialEntryDueDate,(112))))  
				,(CONVERT([int],CONVERT([varchar](8),InvoiceDate,(112))))  
				,(CONVERT([int],CONVERT([varchar](8),OriginalDueDate,(112))))  
				,(CONVERT([int],CONVERT([varchar](8),PostingDate,(112))))  


				, SRC.CurrencyCode
				, SRC.Amount
				, SRC.AmountLCYExcVAT
				, SRC.AmountLCYIncVAT
				, SRC.CreditAmount
				, SRC.CreditAmountLCY
				, SRC.DebitAmount
				, SRC.DebitAmountLCY
				, SRC.LedgerEntryAmount

				, @_ExecutionId 
				, GETUTCDATE() 

			FROM	#Src 
			WHERE	RN = 1 ; 


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Src S ;

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