CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_DimVendorLedgerEntry
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendorLedgerEntry]';
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendorLedgerEntry]');
	--DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendorLedgerEntry]');
	DECLARE @LastExecId INT = (SELECT MAX(LastExecutionId) FROM FabricDb.ETL.ProcessMap);
	EXEC dbo.usp_Update_DimVendorLedgerEntry @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM dbo.DimVendorLedgerEntry ; 
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

			TRUNCATE TABLE dbo.DimVendorLedgerEntry ; 

			INSERT INTO dbo.DimVendorLedgerEntry ( 
				VendorLedgerEntrySk, VendorLedgerEntryNo, DetailedLedgerEntryNo, BcCompanySk, VendorSk, VendorPostingGroupSK, GlBalAccountSk
					,GlDimensionCodeSk, PaymentTermsSK, LedgerEntryUserSk, DetailedLedgerEntryUserSk
							,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			SELECT 
				VendorLedgerEntrySk, VendorLedgerEntryNo, DetailedLedgerEntryNo, BcCompanySk, VendorSk, VendorPostingGroupSK, GlBalAccountSk
					,GlDimensionCodeSk, PaymentTermsSK, LedgerEntryUserSk, DetailedLedgerEntryUserSk
							,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			FROM	(VALUES	(	
								-1 , -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 
									, @_ExecutionId, GETUTCDATE()   ) 
					)	AS T(	
				VendorLedgerEntrySk, VendorLedgerEntryNo, DetailedLedgerEntryNo, BcCompanySk, VendorSk, VendorPostingGroupSK, GlBalAccountSk
					,GlDimensionCodeSk, PaymentTermsSK, LedgerEntryUserSk, DetailedLedgerEntryUserSk
							,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimVendorLedgerEntry B 
				WHERE	B.VendorLedgerEntrySk = T.VendorLedgerEntrySk  
			) ; 


			SELECT	 
				 VendorLedgerEntryNo	= VL.EntryNo 
				,DetailedLedgerEntryNo	= ISNULL(VLD.EntryNo , -1)
				,BcCompanySk			= ISNULL(BC.BcCompanySk , -1) 

				,VendorPostingGroupSK		= ISNULL(PG.VendorPostingGroupSK , -1) 
				,VendorSk					= ISNULL(V.VendorSk , -1) 
				,PaymentTermsSK				= ISNULL(PT.PaymentTermsSK , -1) 
				,GlDimensionCodeSk			= ISNULL(DC.GlDimensionCodeSk, -1) 
				,GlBalAccountSk				= ISNULL(GB.GlBalAccountSk, -1) 
				,LedgerEntryUserSk			= ISNULL(BCV.BcUserSk, -1) 
				,DetailedLedgerEntryUserSk	= ISNULL(BCL.BcUserSk, -1) 

				,CurrencyCode			= IIF(VL.CurrencyCode = '', 'GBP', VL.CurrencyCode) 
				,VL.[Description] 

				,InvoiceNo				= VL.ExternalDocumentNo
				,VL.DocumentNo 
				,VL.DocumentType 
				,VL.ExternalDocumentNo 
				,VL.TransactionNo 
				,VL.CreditorNo
				,VL.JournalBatchName 

				,VL.OnHold 
				,VL.[Open] 
				,VL.PaymentReference 
				,VL.Positive 
				,VL._crda_ActiveFromDateTime

			INTO #Source 
			FROM		lh_SilverLayer.BC.HISTORY_VendorLedgerEntry		VL 

			LEFT JOIN	lh_SilverLayer.BC.HISTORY_DetailedVendorLedgEntry	VLD	ON	VLD.VendorLedgerEntryNo = VL.EntryNo
																AND	VLD.BC_CompanyName		= VL.BC_CompanyName
																AND	VLD._crda_isDeleted		= 0  
																AND	VLD._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			LEFT JOIN	dbo.DimBcCompany					BC	ON	BC.BC_CompanyName	= VL.BC_CompanyName 

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

			LEFT JOIN	dbo.DimBcUser						BCV	ON	BCV.BcUserId	= VL.UserID 

			LEFT JOIN	dbo.DimBcUser						BCL	ON	BCL.BcUserId	= VLD.UserID 

			WHERE	VL._crda_isDeleted			= 0  
			AND		VL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
			AND		VL._crda_ActiveFromDateTime >= @_Watermark ; 



			INSERT INTO	dbo.DimVendorLedgerEntry 
			( 
				 VendorLedgerEntrySk 
				,VendorLedgerEntryNo
				,DetailedLedgerEntryNo
				,BcCompanySk

				,VendorSk
				,VendorPostingGroupSK
				,GlBalAccountSk
				,GlDimensionCodeSk
				,PaymentTermsSK
				,LedgerEntryUserSk
				,DetailedLedgerEntryUserSk
				,CurrencyCode
				,[Description]
				,InvoiceNo
				,DocumentNo
				,ExternalDocumentNo
				,DocumentType
				,CreditorNo
				,JournalBatchName
				,TransactionNo
				,OnHold
				,[Open]
				,PaymentReference
				,Positive

				, _crda_CreatedExecutionId 
				, _crda_CreatedDateTime 
			)
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY VendorLedgerEntryNo, DetailedLedgerEntryNo, BcCompanySk) 
				,SRC.VendorLedgerEntryNo
				,SRC.DetailedLedgerEntryNo
				,SRC.BcCompanySk

				,SRC.VendorSk
				,SRC.VendorPostingGroupSK
				,SRC.GlBalAccountSk
				,SRC.GlDimensionCodeSk
				,SRC.PaymentTermsSK
				,SRC.LedgerEntryUserSk
				,SRC.DetailedLedgerEntryUserSk
				,SRC.CurrencyCode
				,SRC.[Description]
				,SRC.InvoiceNo
				,SRC.DocumentNo
				,SRC.ExternalDocumentNo
				,SRC.DocumentType
				,SRC.CreditorNo
				,SRC.JournalBatchName
				,SRC.TransactionNo
				,SRC.OnHold
				,SRC.[Open]
				,SRC.PaymentReference
				,SRC.Positive

				, @_ExecutionId 
				, GETUTCDATE() 
			FROM	#Source SRC 
			ORDER BY VendorLedgerEntryNo, DetailedLedgerEntryNo, BcCompanySk ; 


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