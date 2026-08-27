CREATE   
	PROCEDURE dbo.usp_Update_DimBusinessUnit
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBusinessUnit]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBusinessUnit]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimBusinessUnit]')
	EXEC dbo.usp_Update_DimBusinessUnit @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT *  FROM dbo.DimBusinessUnit ; 
	SELECT Src_hash=_crda_Hash, * from dbo.DimBusinessUnit ; 
	--TRUNCATE TABLE dbo.DimBusinessUnit ; 
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

			TRUNCATE TABLE dbo.DimBusinessUnit ; 

			INSERT INTO dbo.DimBusinessUnit ( 
				BusinessUnitSk, BusinessUnitBk, BusinessUnitName, CurrencyIsoCode, TaxCodeReference, ExpenseItemSubmissionDays, ExpenseItemExchangeRateTolerancePct , 
					CreditNoteFooter, InvoiceFooter, InvoiceBusinessUnitName, InvoiceCurrencyIsoCode, InvoiceTaxCodeNumber, InvoicePaymentTermDays, 
						InvoicingAddress, InvoicingStreetName, InvoicingStreet, InvoicingCity, InvoicingState, InvoicingCountry, InvoicingPostCode , 
							IsOperatingEntity, IsTradingEntity, IsPrimaryOrganisationalEntity, IsSecondaryOrganisationalEntity, IsActive, IsDefault, 
								BudgetCode, TimePattern , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			SELECT 
				BusinessUnitSk, BusinessUnitBk, BusinessUnitName, CurrencyIsoCode, TaxCodeReference, ExpenseItemSubmissionDays, ExpenseItemExchangeRateTolerancePct , 
					CreditNoteFooter, InvoiceFooter, InvoiceBusinessUnitName, InvoiceCurrencyIsoCode, InvoiceTaxCodeNumber, InvoicePaymentTermDays, 
						InvoicingAddress, InvoicingStreetName, InvoicingStreet, InvoicingCity, InvoicingState, InvoicingCountry, InvoicingPostCode , 
							IsOperatingEntity, IsTradingEntity, IsPrimaryOrganisationalEntity, IsSecondaryOrganisationalEntity, IsActive, IsDefault, 
								BudgetCode, TimePattern , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			FROM	(VALUES	(	
						-1 , 'UnknownRecord', 'UnknownRecord', 'ZZZ', '', 0, 0, 
							'', '', '', 'ZZZ', '', 0, 
								'', '', '', '', '', '', '', 
									0, 0, 0, 0, 0, 0, 
										'ZZZ', '', 
											'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
												,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
								BusinessUnitSk, BusinessUnitBk, BusinessUnitName, CurrencyIsoCode, TaxCodeReference, ExpenseItemSubmissionDays, ExpenseItemExchangeRateTolerancePct , 
									CreditNoteFooter, InvoiceFooter, InvoiceBusinessUnitName, InvoiceCurrencyIsoCode, InvoiceTaxCodeNumber, InvoicePaymentTermDays, 
										InvoicingAddress, InvoicingStreetName, InvoicingStreet, InvoicingCity, InvoicingState, InvoicingCountry, InvoicingPostCode , 
											IsOperatingEntity, IsTradingEntity, IsPrimaryOrganisationalEntity, IsSecondaryOrganisationalEntity, IsActive, IsDefault, 
												BudgetCode, TimePattern , 
													_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
														,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimBusinessUnit B 
				WHERE	B.BusinessUnitSk = T.BusinessUnitSk 
			) ; 


			SELECT	BusinessUnitBk			= T.Id , 
					T.CurrencyIsoCode ,	
					BusinessUnitName		= T.[Name] , 
					TaxCodeReference		= ISNULL(T.KimbleOne__TaxCodeReference__c , '') , 
					ExpenseItemSubmissionDays			= ISNULL(T.KimbleOne__ExpenseItemSubmissionDays__c , 0) , 
					ExpenseItemExchangeRateTolerancePct	= T.KimbleOne__ExpenseItemExchangeRateTolerancePct__c , 
					CreditNoteFooter		= ISNULL(LEFT(T.KimbleOne__CreditNoteFooter__c, 1024), ''), 
					InvoiceFooter			= ISNULL(LEFT(T.KimbleOne__InvoiceFooter__c, 1024), '') , 
					InvoiceBusinessUnitName	= ISNULL(T.KimbleOne__InvoicingBusinessUnitName__c , '') , 
					InvoiceCurrencyIsoCode	= ISNULL(T.KimbleOne__InvoicingCurrencyIsoCode__c , '') , 
					InvoiceTaxCodeNumber	= ISNULL(T.KimbleOne__InvoiceTaxCodeNumber__c, '') ,
					InvoicePaymentTermDays	= ISNULL(T.KimbleOne__InvoicePaymentTermDays__c,0) , 
					InvoiceAddress			= ISNULL(T.KimbleOne__InvoicingAddress__c,	'') , 
					InvoiceStreetName		= ISNULL(T.KimbleOne__InvoicingStreetName__c,	'') , 
					InvoiceStreet			= ISNULL(T.KimbleOne__InvoicingStreet__c,	'') , 
					InvoiceState			= ISNULL(T.KimbleOne__InvoicingState__c,	'') , 
					InvoiceCity				= ISNULL(T.KimbleOne__InvoicingCity__c,	'') , 
					InvoiceCountry			= ISNULL(T.KimbleOne__InvoicingCountry__c,	'') , 
					InvoicePostCode			= ISNULL(T.KimbleOne__InvoicingPostalCode__c,	'') , 
					IsOperatingEntity		= ISNULL(T.KimbleOne__IsOperatingEntity__c , 0 ) , 
					IsTradingEntity			= ISNULL(T.KimbleOne__IsTradingEntity__c , 0 ) , 
					IsPrimaryOrganisationalEntity	= ISNULL(T.KimbleOne__IsPrimaryOrganisationalEntity__c , 0 ) , 
					IsSecondaryOrganisationalEntity	= ISNULL(T.KimbleOne__IsSecondaryOrganisationalEntity__c , 0 ) , 
					IsActive				= T.isActive__c , 
					IsDefault				= T.isDefault__c , 
					BudgetCode				= ISNULL(T.Budget_Code__c, '') , 
					TimePattern				= P.[Name] , 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_BusinessUnit	T 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_TimePattern	P	ON	P.Id = T.KimbleOne__TimePattern__c 
																		AND P._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
																		AND	P._crda_isDeleted = 0
			CROSS APPLY (
			SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
						  T.CurrencyIsoCode	
						, T.[Name]	 
						, T.KimbleOne__TaxCodeReference__c	
						, T.KimbleOne__ExpenseItemSubmissionDays__c	
						, T.KimbleOne__ExpenseItemExchangeRateTolerancePct__c	
						, T.KimbleOne__CreditNoteFooter__c	
						, T.KimbleOne__InvoiceFooter__c	
						, T.KimbleOne__InvoicingBusinessUnitName__c 	
						, T.KimbleOne__InvoicingCurrencyIsoCode__c	
						, T.KimbleOne__InvoiceTaxCodeNumber__c	
						, T.KimbleOne__InvoicePaymentTermDays__c	
						, T.KimbleOne__InvoicingAddress__c	
						, T.KimbleOne__InvoicingStreetName__c	
						, T.KimbleOne__InvoicingStreet__c 
						, T.KimbleOne__InvoicingState__c 
						, T.KimbleOne__InvoicingCity__c	
						, T.KimbleOne__InvoicingCountry__c	
						, T.KimbleOne__InvoicingPostalCode__c	
						, T.KimbleOne__IsOperatingEntity__c	
						, T.KimbleOne__IsTradingEntity__c	
						, T.KimbleOne__IsPrimaryOrganisationalEntity__c	
						, T.KimbleOne__IsSecondaryOrganisationalEntity__c	
						, T.isActive__c	
						, T.isDefault__c	
						, T.Budget_Code__c	
						, P.[Name] 	
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime	> @_Watermark  
			AND		T._crda_isDeleted			= 0  ; 
			--SELECT COUNT(1) from #Source

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'BusinessUnit';


			INSERT INTO dbo.DimBusinessUnit
			( 
				BusinessUnitSk , 
				BusinessUnitBk , 
				BusinessUnitName ,
				CurrencyIsoCode , 
				TaxCodeReference , 
				ExpenseItemSubmissionDays , 
				ExpenseItemExchangeRateTolerancePct , 
				CreditNoteFooter , 
				InvoiceFooter , 
				InvoiceBusinessUnitName , 
				InvoiceCurrencyIsoCode , 
				InvoiceTaxCodeNumber , 
				InvoicePaymentTermDays , 
				InvoicingAddress , 
				InvoicingStreetName , 
				InvoicingStreet , 
				InvoicingCity , 
				InvoicingState , 
				InvoicingCountry , 
				InvoicingPostCode , 
				IsOperatingEntity , 
				IsTradingEntity , 
				IsPrimaryOrganisationalEntity , 
				IsSecondaryOrganisationalEntity , 
				IsActive , 
				IsDefault , 
				BudgetCode , 
				TimePattern 

				,_crda_ActiveFromDate 
				,_crda_ActiveToDate 
				,_crda_ActiveFromDateSk 
				,_crda_ActiveToDateSk 
				,IsCurrent 
				,_crda_Hash 
				,_crda_CreatedExecutionId  
				,_crda_CreatedDateTime 
				,_crda_isDeleted
			)
			SELECT  
				RN= ROW_NUMBER()OVER (ORDER BY SRC.BusinessUnitBk, SRC._crda_ActiveFromDateTime ) , 
				SRC.BusinessUnitBk , 
				SRC.BusinessUnitName , 
				SRC.CurrencyIsoCode , 
				SRC.TaxCodeReference , 
				SRC.ExpenseItemSubmissionDays , 
				SRC.ExpenseItemExchangeRateTolerancePct , 
				SRC.CreditNoteFooter , 
				SRC.InvoiceFooter , 
				SRC.InvoiceBusinessUnitName , 
				SRC.InvoiceCurrencyIsoCode , 
				SRC.InvoiceTaxCodeNumber , 
				SRC.InvoicePaymentTermDays , 
				SRC.InvoiceAddress , 
				SRC.InvoiceStreetName , 
				SRC.InvoiceStreet , 
				SRC.InvoiceCity , 
				SRC.InvoiceState , 
				SRC.InvoiceCountry , 
				SRC.InvoicePostCode , 
				SRC.IsOperatingEntity , 
				SRC.IsTradingEntity , 
				SRC.IsPrimaryOrganisationalEntity , 
				SRC.IsSecondaryOrganisationalEntity , 
				SRC.IsActive , 
				SRC.IsDefault , 
				SRC.BudgetCode , 
				SRC.TimePattern 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM	#Source			SRC 
			ORDER BY SRC.BusinessUnitBk, SRC._crda_ActiveFromDateTime ;


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