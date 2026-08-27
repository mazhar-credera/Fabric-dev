CREATE  
	PROCEDURE dbo.usp_Update_FactVendorLedgerEntry
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS 
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactVendorLedgerEntry]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactVendorLedgerEntry]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactVendorLedgerEntry]')
	EXEC dbo.usp_Update_FactVendorLedgerEntry @ExecutionId = @ExecutionId, @Watermark ='2025-10-17 23:37:16.9300000', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM dbo.FactVendorLedgerEntry ; --159607
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

			DROP TABLE IF EXISTS #Src ;

			TRUNCATE TABLE dbo.FactVendorLedgerEntry ; 


			SELECT	 
				 DV.VendorLedgerEntrySk 
				,BcCompanySk				= ISNULL(BC.BcCompanySk , -1) 

				,VendorPostingGroupSK		= ISNULL(PG.VendorPostingGroupSK , -1) 
				,VendorSk					= ISNULL(V.VendorSk , -1) 
				,GlBalAccountSk				= ISNULL(GB.GlBalAccountSk, -1) 
				,GlDimensionCodeSk			= ISNULL(DC.GlDimensionCodeSk, -1) 
				,PaymentTermsSK				= ISNULL(PT.PaymentTermsSK , -1) 
				,BcVatInfoSk				= ISNULL(DVI.BcVatInfoSk, -1) 
				,LedgerEntryUserSk			= ISNULL(BCV.BcUserSk, -1) 
				,DetailedLedgerEntryUserSk	= ISNULL(BCL.BcUserSk, -1) 

				,ClosedAtDate			= IIF(VL.ClosedAtDate < '19000201', NULL, CAST(VL.ClosedAtDate AS DATE) )
				,DocumentDate			= IIF(VL.DocumentDate < '19000201', NULL, CAST(VL.DocumentDate AS DATE) )
				,DueDate				= IIF(VL.DueDate < '19000201', NULL, CAST(VL.DueDate AS DATE) )
				,PostingDate			= IIF(VL.PostingDate < '19000201', NULL, CAST(VL.PostingDate AS DATE) ) 
				,InvoiceDate			= IIF(VL.DocumentDate < '19000201', NULL, CAST(VL.DocumentDate AS DATE) ) 

				,CurrencyCode			= IIF(VL.CurrencyCode = '', 'GBP', VL.CurrencyCode) 

				,VLD.Amount	
				,VLD.AmountLCY 
				,VLD.CreditAmount 
				,VLD.CreditAmountLCY  
				,VLD.DebitAmount 
				,VLD.DebitAmountLCY   

				,VL._crda_ActiveFromDateTime

			INTO #Src 
			FROM		lh_SilverLayer.BC.HISTORY_VendorLedgerEntry		VL 

			LEFT JOIN	lh_SilverLayer.BC.HISTORY_DetailedVendorLedgEntry	VLD	ON	VLD.VendorLedgerEntryNo = VL.EntryNo
																AND	VLD.BC_CompanyName		= VL.BC_CompanyName
																AND	VLD._crda_isDeleted		= 0  
																AND	VLD._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	dbo.DimBcCompany					BC	ON	BC.BC_CompanyName	= VL.BC_CompanyName 

			INNER JOIN	dbo.DimVendorLedgerEntry			DV	ON	DV.VendorLedgerEntryNo	= VL.EntryNo
																AND	DV.DetailedLedgerEntryNo= ISNULL(VLD.EntryNo , -1)
																AND	DV.BcCompanySk			= BC.BcCompanySk 

			LEFT JOIN	dbo.DimVendor						V	ON	V.[No]			= VL.VendorNo 
																AND	V.BcCompanySk	= BC.BcCompanySk 

			LEFT JOIN	dbo.DimPaymentTerms					PT	ON	V.PaymentTermsCode= PT.Code
																AND	V.BcCompanySk	  = PT.BcCompanySk 

			LEFT JOIN	dbo.DimVendorPostingGroup			PG	ON	PG.VendorPostingGroupName= VL.VendorPostingGroup
																AND	PG.BcCompanySk		= BC.BcCompanySk 

			LEFT JOIN	dbo.DimGlDimensionCode				DC	ON	DC.GlobalDimension1Code	= VL.GlobalDimension1Code 
																AND	DC.GlobalDimension2Code	= VL.GlobalDimension2Code 

			LEFT JOIN	dbo.DimGlBalAccount					GB	ON	GB.BalAccountNo		= VL.BalAccountNo 
																AND	GB.BalAccountType	= VL.BalAccountType  

			LEFT JOIN	dbo.DimBcVatINfo					DVI	ON	DVI.VatBusPostingGroup	= VLD.VatBusPostingGroup 
																AND	DVI.VatProdPostingGroup	= VLD.VatProdPostingGroup  

			LEFT JOIN	dbo.DimBcUser						BCV	ON	BCV.BcUserId	= VL.UserID 

			LEFT JOIN	dbo.DimBcUser						BCL	ON	BCL.BcUserId	= VLD.UserID 

			WHERE	VL._crda_isDeleted			= 0  
			AND		VL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			AND		VL._crda_ActiveFromDateTime >= @_Watermark ; 
			/*SELECT * FROM #Src WHERE VendorLedgerEntrySk is null
			SELECT count(1), SUM(IIF(VendorLedgerEntrySk is null, 1,0)) FROM #Src */


			INSERT INTO	dbo.FactVendorLedgerEntry 
			( 
				 VendorLedgerEntrySk
				,BcCompanySk

				,VendorSk
				,VendorPostingGroupSK
				,GlBalAccountSk
				,GlDimensionCodeSk
				,PaymentTermsSK
				,BcVatInfoSk
				,LedgerEntryUserSk
				,DetailedLedgerEntryUserSk

				,ClosedAtDate
				,DocumentDate
				,DueDate
				,PostingDate
				,InvoiceDate 

				,ClosedAtDateSk	
				,DocumentDateSk	
				,DueDateSk		
				,PostingDateSk	
				,InvoiceDateSk	

				,CurrencyCode
				,Amount
				,AmountLCY
				,CreditAmount
				,CreditAmountLCY
				,DebitAmount
				,DebitAmountLCY

				, _crda_CreatedExecutionId 
				, _crda_CreatedDateTime 
			)
			SELECT 
				  SRC.VendorLedgerEntrySk
				, SRC.BcCompanySk

				, SRC.VendorSk
				, SRC.VendorPostingGroupSK
				, SRC.GlBalAccountSk
				, SRC.GlDimensionCodeSk
				, SRC.PaymentTermsSK
				, SRC.BcVatInfoSk
				, SRC.LedgerEntryUserSk
				, SRC.DetailedLedgerEntryUserSk

				, SRC.ClosedAtDate 
				, SRC.DocumentDate
				, SRC.DueDate
				, SRC.PostingDate
				, SRC.InvoiceDate

				,CONVERT([int],CONVERT([varchar](8),ClosedAtDate,(112))) 
				,CONVERT([int],CONVERT([varchar](8),DocumentDate,(112))) 
				,CONVERT([int],CONVERT([varchar](8),DueDate,(112))) 
				,CONVERT([int],CONVERT([varchar](8),PostingDate,(112))) 
				,CONVERT([int],CONVERT([varchar](8),InvoiceDate,(112))) 

				, SRC.CurrencyCode
				, SRC.Amount
				, SRC.AmountLCY
				, SRC.CreditAmount
				, SRC.CreditAmountLCY
				, SRC.DebitAmount
				, SRC.DebitAmountLCY

				, @_ExecutionId 
				, GETUTCDATE() 
			FROM	#Src SRC 

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