CREATE   
	PROCEDURE dbo.usp_Update_DimAccount
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS 
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	Pks, Unique Contraints, FKs are not enforced so Groundhog day everything 

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimAccount]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimAccount]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimAccount]')
	EXEC dbo.usp_Update_DimAccount @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimAccount ORDER BY AccountSk
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

			TRUNCATE TABLE dbo.DimAccount ; 

			INSERT INTO dbo.DimAccount ( 
				AccountSk, AccountBk, [Name], AccountDisplayName, FriendlyName, AnonymisedAccountName, [Description], [Type], [Status] , 
					AccountDirectorSk, OwnerSk, BusinessUnitSk, Industry, AnnualRevenue, NumberOfEmployees , UrlToKanataRecord, ParentAccountSk, 
						SICCode, CurrencyIsoCode, Phone, WebsiteLink, TaxCodeReference, BillingContactBk, BillingStreet, BillingCity , 
							BillingState, BillingCountry, BillingPostCode, ShippingStreet, ShippingCity, ShippingState, ShippingCountry, ShippingPostCode, InvoicePaymentTermDays , 
								InvoiceCurrencyIsoCode, SupplierInvoiceMatchingTolerancePct, AutoApproveInvoice, IsCustomer, IsSupplier, OwnerIsCurrentEmployee, CredsAvailable, NAVVATBusPostGroup, 
									ServiceGroup, ServiceIndustry, SectorName, OmnicomFinanceCode, TotalSalesWon, ActiveProjects, 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			SELECT 
				AccountSk, AccountBk, [Name], AccountDisplayName, FriendlyName, AnonymisedAccountName, [Description], [Type], [Status] , 
					AccountDirectorSk,  OwnerSk, BusinessUnitSk, Industry, AnnualRevenue, NumberOfEmployees , UrlToKanataRecord, ParentAccountSk, 
						SICCode, CurrencyIsoCode, Phone, WebsiteLink, TaxCodeReference, BillingContactBk, BillingStreet, BillingCity , 
							BillingState, BillingCountry, BillingPostCode, ShippingStreet, ShippingCity, ShippingState, ShippingCountry, ShippingPostCode, InvoicePaymentTermDays , 
								InvoiceCurrencyIsoCode, SupplierInvoiceMatchingTolerancePct, AutoApproveInvoice, IsCustomer, IsSupplier, OwnerIsCurrentEmployee, CredsAvailable, NAVVATBusPostGroup, 
									ServiceGroup, ServiceIndustry, SectorName, OmnicomFinanceCode, TotalSalesWon, ActiveProjects, 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			FROM	(VALUES	(	
						-1 , 'UnknownRecord', 'UnknownRecord', 'UnknownRecord', 'UnknownRecord', 'UnknownRecord', 'UnknownRecord', '', '',
							-1, -1, -1, '', 0, 0 , '', -1, 
								'', '', '', '', '', '', '', '',
									'', '', '', '', '', '', '', '', 0, 
										'', 0, 0, 0, 0, 0, '', '',
											'', '', '', '', 0, 0, 
												'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
													,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
							AccountSk, AccountBk, [Name], AccountDisplayName, FriendlyName, AnonymisedAccountName, [Description], [Type], [Status] , 
								AccountDirectorSk, OwnerSk, BusinessUnitSk, Industry, AnnualRevenue, NumberOfEmployees , UrlToKanataRecord, ParentAccountSk, 
									SICCode, CurrencyIsoCode, Phone, WebsiteLink, TaxCodeReference, BillingContactBk, BillingStreet, BillingCity , 
										BillingState, BillingCountry, BillingPostCode, ShippingStreet, ShippingCity, ShippingState, ShippingCountry, ShippingPostCode, InvoicePaymentTermDays , 
											InvoiceCurrencyIsoCode, SupplierInvoiceMatchingTolerancePct, AutoApproveInvoice, IsCustomer, IsSupplier, OwnerIsCurrentEmployee, CredsAvailable, NAVVATBusPostGroup, 
												ServiceGroup, ServiceIndustry, SectorName, OmnicomFinanceCode, TotalSalesWon, ActiveProjects, 
													_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
														,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimAccount B 
				WHERE	B.AccountSk = T.AccountSk 
			) ; 


			SELECT 	AccountBk				= T.Id , 
					[Name]					= LEFT(T.[Name] , 80) ,  
					AccountDisplayName		= ISNULL(T.AccountDisplayName__c , '') , 
					FriendlyName			= ISNULL(T.FriendlyName__c , '') , 
					AnonymisedAccountName	= ISNULL(T.Anonymised_Account_Name__c , '') , 
					[Description]			= ISNULL(T.[Description], ''), 
					[Type]					= ISNULL(T.[Type], '') , 
					[Status]				= ISNULL(T.AccountStatus__c , '') , 
					AccountDirectorSk		= ISNULL(R.ResourceSk , -1) , 
					ParentAccountBk			= T.ParentId , 
					OwnerSk					= ISNULL(K.KimbleUserSk, -1) ,
					BusinessUnitSk				= ISNULL(BU.BusinessUnitSk, -1) ,  
					TradingEntityBusinessUnitSk	= ISNULL(BT.BusinessUnitSk, -1) ,  
					Industry				= ISNULL(T.Industry ,'') , 
					AnnualRevenue			= ISNULL(CAST(T.AnnualRevenue AS DECIMAL(18,2)), 0),	
					NumberOfEmployees		= ISNULL(T.NumberOfEmployees, 0),
					SICCode					= ISNULL(T.Sic ,'') , 
					T.CurrencyIsoCode ,	
					Phone					= ISNULL(T.Phone, '') , 
					WebsiteLink				= ISNULL(T.Website, '') , 
					TaxCodeReference		= ISNULL(T.KimbleOne__TaxCodeReference__c , '') , 
					BillingContactBk		= ISNULL(T.KimbleOne__BillingContact__c , '') , 
					BillingParentAccountBk	= T.KimbleOne__BillingParentAccount__c , 
					BillingStreet			= ISNULL(T.BillingStreet , '') , 
					BillingCity				= ISNULL(T.BillingCity, '') , 
					BillingState			= ISNULL(T.BillingState , '') , 
					BillingCountry			= ISNULL(T.BillingCountry , '') , 
					BillingPostCode			= ISNULL(T.BillingPostalCode , 	'') , 
					ShippingStreet			= ISNULL(T.ShippingStreet , '') , 
					ShippingCity			= ISNULL(T.ShippingCity , ''), 
					ShippingState			= ISNULL(T.ShippingState , 	'') , 
					ShippingCountry			= ISNULL(T.ShippingCountry , '') , 
					ShippingPostCode		= ISNULL(T.ShippingPostalCode , '') , 
					InvoicePaymentTermDays	= CAST(T.KimbleOne__InvoicePaymentTermDays__c AS INT), 
					InvoiceCurrencyIsoCode	= ISNULL(T.KimbleOne__InvoicingCurrencyIsoCode__c,''), 
					SupplierInvoiceMatchingTolerancePct	= ISNULL(CAST(T.KimbleOne__SupplierInvoiceMatchingTolerancePct__c AS DECIMAL(5,2)), 0) , 
					AutoApproveInvoice		= T.AutoApproveInvoice__c ,
					IsCustomer				= T.KimbleOne__IsCustomer__c , 
					IsSupplier				= T.KimbleOne__IsSupplier__c , 
					OwnerIsCurrentEmployee	= T.OwnerIsCurrentEmployee__c ,
					CredsAvailable			= T.CredsAvailable__c ,
					NAVVATBusPostGroup		= ISNULL(T.NAVVATBusPostGroup__c , '') , 
					ServiceGroup			= ISNULL(T.ServiceGroup__c , '') , 
					ServiceIndustry			= ISNULL(T.ServingIndustry__c , '') , 
					SectorName				= ISNULL(T.SectorName__c , '') , 
					OmnicomFinanceCode		= ISNULL(T.Omnicom_Finance_Code__c , '') , 
					TotalSalesWon			= ISNULL(CAST(T.KC_WonSales__c AS INT), 0) , 
					ActiveProjects			= ISNULL(CAST(T.KC_ActiveProjects__c  AS INT), 0) , 
					MsaExpiryDate			= CONVERT (DATE, T.MSA_expiry_date__c ),
					MsaSigningDate			= CONVERT (DATE, T.MSA_signing_date__c ) ,
					ActualHoursBilling		= T.Actual_hours_billing__c , 
					SageAccountReference	= T.SageAccountReference__c ,
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_Account	T 
			LEFT JOIN	dbo.DimResource			R	ON	R.ResourceBk = T.AccountDirector__c 
													AND	T._crda_ActiveFromDateTime BETWEEN R._crda_ActiveFromDate AND R._crda_ActiveToDate
													--AND	R.IsCurrent = 1
			LEFT JOIN	dbo.DimKimbleUser		K	ON	K.KimbleUserBk = T.OwnerId
													AND	T._crda_ActiveFromDateTime BETWEEN K._crda_ActiveFromDate AND K._crda_ActiveToDate
													--AND	K.IsCurrent = 1 
			LEFT JOIN	dbo.DimBusinessUnit		BU	ON	BU.BusinessUnitBk = T.KimbleOne__BusinessUnit__c 
													AND	T._crda_ActiveFromDateTime BETWEEN BU._crda_ActiveFromDate AND BU._crda_ActiveToDate
													--AND	BU.IsCurrent = 1
			LEFT JOIN	dbo.DimBusinessUnit		BT	ON	BT.BusinessUnitBk = T.KimbleOne__BusinessUnitTradingEntity__c 
													AND	T._crda_ActiveFromDateTime BETWEEN BT._crda_ActiveFromDate AND BT._crda_ActiveToDate
													--AND	BT.IsCurrent = 1
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.[Name]	
								, T.AccountDisplayName__c	 
								, T.FriendlyName__c	
								, T.Anonymised_Account_Name__c	
								, LEFT(T.[Description], 2048)
								, T.[Type]	
								, T.AccountStatus__c	
								, R.ResourceSk   
								, T.ParentId   
								, K.KimbleUserSk	
								, BU.BusinessUnitSk 
								, BT.BusinessUnitSk	
								, T.Industry	
								, T.AnnualRevenue	
								, T.NumberOfEmployees	
								, T.Sic	
								, T.CurrencyIsoCode	
								, T.Phone	
								, T.Website	
								, T.KimbleOne__TaxCodeReference__c	
								, T.KimbleOne__BillingContact__c  	
								, T.KimbleOne__BillingParentAccount__c 
								, T.BillingStreet	
								, T.BillingCity	
								, T.BillingState	
								, T.BillingCountry	
								, T.BillingPostalCode	
								, T.ShippingStreet	
								, T.ShippingCity	
								, T.ShippingState	
								, T.ShippingCountry	
								, T.ShippingPostalCode	
								, T.KimbleOne__InvoicePaymentTermDays__c	
								, T.KimbleOne__InvoicingCurrencyIsoCode__c	
								, T.KimbleOne__SupplierInvoiceMatchingTolerancePct__c	
								, T.AutoApproveInvoice__c	
								, T.KimbleOne__IsCustomer__c	
								, T.KimbleOne__IsSupplier__c	
								, T.OwnerIsCurrentEmployee__c	
								, T.CredsAvailable__c	
								, T.NAVVATBusPostGroup__c	
								, T.ServiceGroup__c	
								, T.ServingIndustry__c	
								, T.SectorName__c	
								, T.Omnicom_Finance_Code__c	
								, T.KC_WonSales__c	
								, T.KC_ActiveProjects__c 
								, CONVERT(DATETIME2(6), T.MSA_expiry_date__c, 121) 
								, CONVERT(DATETIME2(6), T.MSA_signing_date__c, 121) 
								, T.Actual_hours_billing__c 
								, T.SageAccountReference__c 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 

--SELECT top 1000 LEN([Description]), * FROM #Source ORDER BY LEN([Description]) DESC

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Account';

			INSERT INTO dbo.DimAccount(
				 AccountSk
				,AccountBk
				,[Name]
				,AccountDisplayName
				,FriendlyName
				,AnonymisedAccountName
				,[Description]
				,[Type]
				,[Status]
				,AccountDirectorSk
				,OwnerSk
				,BusinessUnitSk
				,TradingEntityBusinessUnitSk
				,Industry
				,AnnualRevenue
				,NumberOfEmployees
				,SICCode
				,CurrencyIsoCode
				,Phone
				,WebsiteLink
				,TaxCodeReference
				,ParentAccountSk 
				,BillingContactBk
				,BillingStreet
				,BillingCity
				,BillingState
				,BillingCountry
				,BillingPostCode
				,ShippingStreet
				,ShippingCity
				,ShippingState
				,ShippingCountry
				,ShippingPostCode
				,InvoicePaymentTermDays
				,InvoiceCurrencyIsoCode
				,SupplierInvoiceMatchingTolerancePct
				,AutoApproveInvoice
				,IsCustomer
				,IsSupplier
				,OwnerIsCurrentEmployee
				,CredsAvailable
				,NAVVATBusPostGroup
				,ServiceGroup
				,ServiceIndustry
				,SectorName
				,OmnicomFinanceCode
				,TotalSalesWon
				,ActiveProjects
				,MsaExpiryDate 
				,MsaSigningDate 
				,ActualHoursBilling 
				,SageAccountReference 
				,UrlToKanataRecord 
				,SectorGroups 

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
				 RN= ROW_NUMBER()OVER (ORDER BY AccountBk, SRC._crda_ActiveFromDateTime)
				,SRC.AccountBk
				,SRC.[Name]
				,SRC.AccountDisplayName
				,SRC.FriendlyName
				,SRC.AnonymisedAccountName
				,SRC.[Description]
				,SRC.[Type]
				,SRC.[Status]
				,SRC.AccountDirectorSk
				,SRC.OwnerSk
				,SRC.BusinessUnitSk
				,SRC.TradingEntityBusinessUnitSk
				,SRC.Industry
				,SRC.AnnualRevenue
				,SRC.NumberOfEmployees
				,SRC.SICCode
				,SRC.CurrencyIsoCode
				,SRC.Phone
				,SRC.WebsiteLink
				,SRC.TaxCodeReference
				,-1 
				,SRC.BillingContactBk
				,SRC.BillingStreet
				,SRC.BillingCity
				,SRC.BillingState
				,SRC.BillingCountry
				,SRC.BillingPostCode
				,SRC.ShippingStreet
				,SRC.ShippingCity
				,SRC.ShippingState
				,SRC.ShippingCountry
				,SRC.ShippingPostCode
				,SRC.InvoicePaymentTermDays
				,SRC.InvoiceCurrencyIsoCode
				,SRC.SupplierInvoiceMatchingTolerancePct
				,SRC.AutoApproveInvoice
				,SRC.IsCustomer
				,SRC.IsSupplier
				,SRC.OwnerIsCurrentEmployee
				,SRC.CredsAvailable
				,SRC.NAVVATBusPostGroup
				,SRC.ServiceGroup
				,SRC.ServiceIndustry
				,SRC.SectorName
				,SRC.OmnicomFinanceCode
				,SRC.TotalSalesWon
				,SRC.ActiveProjects
				,SRC.MsaExpiryDate 
				,SRC.MsaSigningDate 
				,SRC.ActualHoursBilling 
				,SRC.SageAccountReference 
				,CONCAT('https://dmw.lightning.force.com/lightning/r/Account/',AccountBk, '/view')
				,case when [SectorName]='Public Sector' then 'PS' when [SectorName]='Insurance' OR [SectorName]='Financial Services' then 'FSI' when [SectorName]='Oil, Gas & Utilities' OR [SectorName]='Commercial' then 'E&C' when [SectorName]='Portfolio' then 'PF' else 'Not Specified' end

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM 	#Source	SRC 
			ORDER BY SRC.AccountBk, SRC._crda_ActiveFromDateTime ; 



			--Update ParentAccountSk in dbo.DimAccount
			;WITH cteParentAccountSk
			AS(
				SELECT	SrcBk=S.AccountBk, SrcParentBk=S.ParentAccountBk, 
						TgtSk=X.AccountSk, TgtBk=X.AccountBk
				FROM	#Source	S  
				LEFT JOIN (
					SELECT	K.AccountSk, K.AccountBk
					FROM	dbo.DimAccount K 
					WHERE	K.IsCurrent = 1
					GROUP BY K.AccountSk, K.AccountBk
				) X	ON X.AccountBk = S.ParentAccountBk 
			) 
			UPDATE	MC 
			SET		MC.ParentAccountSk = ISNULL(TgtSk , -1)
			FROM	dbo.DimAccount	MC 
			INNER JOIN cteParentAccountSk		MK	ON	MK.SrcBk = MC.AccountBk ; 

			--Update BillingParentAccountSk in dbo.DimAccount
			;WITH cteBillingParentAccountSk
			AS(
				SELECT	SrcBk=S.AccountBk, SrcParentBk=S.BillingParentAccountBk, 
						TgtSk=X.AccountSk, TgtBk=X.AccountBk
				FROM	#Source	S  
				LEFT JOIN (
					SELECT	K.AccountSk, K.AccountBk
					FROM	dbo.DimAccount K 
					WHERE	K.IsCurrent = 1
					GROUP BY K.AccountSk, K.AccountBk
				) X	ON X.AccountBk = S.BillingParentAccountBk 
			) 
			UPDATE	MC 
			SET		MC.BillingParentAccountSk = ISNULL(TgtSk , -1)
			FROM	dbo.DimAccount					MC 
			INNER JOIN cteBillingParentAccountSk	MK	ON	MK.SrcBk = MC.AccountBk ; 


			UPDATE	A
			SET		A.AccountDirectorSk = R.ResourceSk 
			FROM		lh_SilverLayer.Kantata.HISTORY_Account	T 
			INNER JOIN	dbo.DimAccount			A	ON	A.AccountBk = T.Id 
													AND A.IsCurrent = 1
			INNER JOIN	dbo.DimResource			R	ON	R.ResourceBk = T.AccountDirector__c 
													AND	R.IsCurrent = 1
			WHERE	T._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
			AND		T._crda_isDeleted = 0  
			AND		R.ResourceSk <> A.AccountDirectorSk ; 


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