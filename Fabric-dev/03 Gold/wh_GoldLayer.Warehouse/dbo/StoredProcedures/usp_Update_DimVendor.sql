CREATE --OR ALTER 
	PROCEDURE dbo.usp_Update_DimVendor
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , /*Not used*/
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendor]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendor]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendor]')
	EXEC dbo.usp_Update_DimVendor @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM [dbo].[DimVendor] ORDER BY VendorSk; 
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

			TRUNCATE TABLE dbo.DimVendor ; 

			INSERT INTO dbo.DimVendor ( 
				VendorSk, [No] ,BcCompanySk ,VendorName ,[CurrencyIsoCode], [Blocked] ,[BlockPaymentTolerance] ,[CashFlowPaymentTermsCode]
					,[FinChargeTermsCode] ,[InvoiceDiscCode] ,[PaymentMethodCode] ,[PaymentTermsCode] ,[PreferredBankAccountCode] ,[PricesIncludingVAT]
						,[ValidateEUVatRegNo] ,[VATBusPostingGroup] ,[VATRegistrationNo] ,[VendorPostingGroup], DataSource, 
								_crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			SELECT	VendorSk, [No] ,BcCompanySk ,VendorName ,[CurrencyIsoCode], [Blocked] ,[BlockPaymentTolerance] ,[CashFlowPaymentTermsCode]
					,[FinChargeTermsCode] ,[InvoiceDiscCode] ,[PaymentMethodCode] ,[PaymentTermsCode] ,[PreferredBankAccountCode] ,[PricesIncludingVAT]
						,[ValidateEUVatRegNo] ,[VATBusPostingGroup] ,[VATRegistrationNo] ,[VendorPostingGroup], DataSource, 
							_crda_CreatedExecutionId, _crda_CreatedDateTime
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , -1, '', 'ZZZ', '', 0, '',  
						 '', '', '', '', '', 0,
							 0, '', '', '', 'UnknownRecord',
								@_ExecutionId, GETUTCDATE()  ) 
					)	AS T(VendorSk, [No] ,BcCompanySk ,VendorName ,[CurrencyIsoCode], [Blocked] ,[BlockPaymentTolerance] ,[CashFlowPaymentTermsCode]
								,[FinChargeTermsCode] ,[InvoiceDiscCode] ,[PaymentMethodCode] ,[PaymentTermsCode] ,[PreferredBankAccountCode] ,[PricesIncludingVAT]
									,[ValidateEUVatRegNo] ,[VATBusPostingGroup] ,[VATRegistrationNo] ,[VendorPostingGroup], DataSource, 
										_crda_CreatedExecutionId, _crda_CreatedDateTime  
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimVendor B 
				WHERE	B.VendorSk = T.VendorSk 
			) ; 


			SELECT 
				B.[No], 
				BcCompanySk		= ISNULL(BC.BcCompanySk, -1) , 
				VendorName		= B.[Name] ,
				B.Blocked , 
				B.BlockPaymentTolerance , 
				B.CashFlowPaymentTermsCode , 
				CurrencyIsoCode = IIF(B.CurrencyCode = '', 'GBP', B.CurrencyCode) ,
				B.FinChargeTermsCode , 
				B.InvoiceDiscCode , 
				B.PaymentMethodCode , 
				B.PaymentTermsCode , 
				B.PreferredBankAccountCode , 
				B.PricesIncludingVAT , 
				B.ValidateEUVatRegNo , 
				B.VATBusPostingGroup , 
				B.VATRegistrationNo , 
				B.VendorPostingGroup , 
				DataSource	= 'Business Central' ,
				B._crda_ActiveFromDateTime 

			INTO #Source
			FROM	lh_SilverLayer.BC.HISTORY_Vendor	B 
			LEFT JOIN dbo.DimBcCompany	BC	ON	BC.BC_CompanyName = B.BC_CompanyName 

			WHERE	B._crda_ActiveFromDateTime	> @_Watermark 
			AND		B._crda_isDeleted			= 0  
			AND		B._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			GROUP BY
				B.[No], 
				ISNULL(BC.BcCompanySk, -1) , 
				B.[Name],
				B.Blocked , 
				B.BlockPaymentTolerance , 
				B.CashFlowPaymentTermsCode , 
				IIF(B.CurrencyCode = '', 'GBP', B.CurrencyCode), 
				B.FinChargeTermsCode , 
				B.InvoiceDiscCode , 
				B.PaymentMethodCode , 
				B.PaymentTermsCode , 
				B.PreferredBankAccountCode , 
				B.PricesIncludingVAT , 
				B.ValidateEUVatRegNo , 
				B.VATBusPostingGroup , 
				B.VATRegistrationNo , 
				B.VendorPostingGroup 
				,AD._crda_Hash
			ORDER BY 
				[No], 
				ISNULL(BC.BcCompanySk, -1);



			INSERT INTO dbo.DimVendor 
			( 
				VendorSk , 
				[No] , 
				BcCompanySk , 
				VendorName , 
				Blocked , 
				BlockPaymentTolerance , 
				CashFlowPaymentTermsCode ,  
				CurrencyIsoCode , 
				FinChargeTermsCode ,  
				InvoiceDiscCode ,  
				PaymentMethodCode ,  
				PaymentTermsCode ,  
				PreferredBankAccountCode ,  
				PricesIncludingVAT ,   
				ValidateEUVatRegNo , 
				VATBusPostingGroup , 
				VATRegistrationNo , 
				VendorPostingGroup , 
				DataSource , 

				_crda_CreatedExecutionId , 
				_crda_CreatedDateTime 
			)
			SELECT
				ROW_NUMBER()OVER (ORDER BY [No], BcCompanySk) , 
				SRC.[No] , 
				SRC.BcCompanySk , 
				SRC.VendorName , 
				SRC.Blocked , 
				SRC.BlockPaymentTolerance , 
				SRC.CashFlowPaymentTermsCode ,  
				SRC.CurrencyIsoCode , 
				SRC.FinChargeTermsCode ,  
				SRC.InvoiceDiscCode ,  
				SRC.PaymentMethodCode ,  
				SRC.PaymentTermsCode ,  
				SRC.PreferredBankAccountCode ,  
				SRC.PricesIncludingVAT ,   
				SRC.ValidateEUVatRegNo , 
				SRC.VATBusPostingGroup , 
				SRC.VATRegistrationNo , 
				SRC.VendorPostingGroup , 
				SRC.DataSource , 

				@_ExecutionId , 
				GETUTCDATE() 
			FROM	#Source SRC 
			ORDER BY [No], BcCompanySk 

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