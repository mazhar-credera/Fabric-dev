CREATE   
	PROCEDURE dbo.usp_Update_DimProduct
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimProduct]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimProduct]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimProduct]')
	EXEC dbo.usp_Update_DimProduct @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	SELECT * FROM dbo.DimProduct ORDER BY ProductSk; 
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

			TRUNCATE TABLE dbo.DimProduct ; 

			INSERT INTO dbo.DimProduct ( 
				ProductSk, ProductBk, [Name], [Description], CurrencyIsoCode,  BusinessUnitSk , IsActive, IsAbstract, IsPrimary, IsRestricted , ProductType , 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT 	ProductSk, ProductBk, [Name], [Description], CurrencyIsoCode,  BusinessUnitSk , IsActive, IsAbstract, IsPrimary, IsRestricted , ProductType , 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord', 'UnknownRecord', 'ZZZ', -1, 0, 0, 0, 0, '', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	ProductSk, ProductBk, [Name], [Description], CurrencyIsoCode,  BusinessUnitSk , IsActive, IsAbstract, IsPrimary, IsRestricted , ProductType , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimProduct B 
				WHERE	B.ProductSk = T.ProductSk 
			) ; 


			SELECT	ProductBk			= T.Id , 
					T.[Name], 
					[Description]		= T.KimbleOne__DefaultDescription__c , 
					T.CurrencyIsoCode , 
					BusinessUnitSk		= ISNULL(BU.BusinessUnitSk, -1) , 

					Sage200NominalAccount	= T.Sage200NominalAccount__c , 
					Sage50NominalAccount	= T.Sage50NominalAccount__c , 
					SageInstantNominalAccount= T.SageInstantNominalAccount__c , 

					IsActive			= T.KimbleOne__IsActive__c , 
					IsAbstract			= T.KimbleOne__IsAbstract__c , 
					IsPrimary			= T.KimbleOne__IsPrimary__c , 
					IsRestricted		= T.KimbleOne__IsRestricted__c , 

					AbstractionTypeBk	= T.KimbleOne__AbstractionType__c , 
					ProductType			= ISNULL(RD.[Name] , '') ,
					NavNominal			= T.NavNominal__c ,

					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_Product	T 
			LEFT JOIN	dbo.DimBusinessUnit						BU	ON	BU.BusinessUnitBk = T.KimbleOne__BusinessUnit__c  
																	AND	BU.IsCurrent = 1
																	AND	BU._crda_isDeleted = 0 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ReferenceData RD	ON	RD.Id = T.KimbleOne__ProductType__c	
																		AND	T._crda_ActiveFromDateTime BETWEEN RD._crda_ActiveFromDateTime AND RD._crda_ActiveToDateTime 
																		AND	RD._crda_isDeleted = 0 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.[Name]	
								, T.KimbleOne__DefaultDescription__c 
								, T.CurrencyIsoCode	
								, ISNULL(BU.BusinessUnitSk, -1)  
								, T.Sage200NominalAccount__c 
								, T.Sage50NominalAccount__c	
								, T.SageInstantNominalAccount__c 
								, T.CurrencyIsoCode	
								, T.KimbleOne__IsActive__c 
								, T.KimbleOne__IsAbstract__c 
								, T.KimbleOne__IsPrimary__c	
								, T.KimbleOne__IsRestricted__c 
								, T.KimbleOne__AbstractionType__c 
								, ISNULL(RD.[Name] , '') 
								, T.NavNominal__c 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Product';

			INSERT INTO dbo.DimProduct
			( 
				ProductSk ,
				ProductBk , 
				[Name] , 			
				[Description] , 
				CurrencyIsoCode , 
				BusinessUnitSk , 		
				Sage200NominalAccount , 
				Sage50NominalAccount , 
				SageInstantNominalAccount , 
				IsActive , 
				IsAbstract , 
				IsPrimary , 
				IsRestricted , 
				AbstractionTypeBk , 
				ProductType ,
				NavNominal , 
				_crda_ActiveFromDate ,
				_crda_ActiveToDate ,
				_crda_Hash , 
				_crda_CreatedExecutionId , 
				_crda_UpdatedExecutionId , 
				_crda_CreatedDateTime ,
				_crda_UpdatedDateTime 
			)
			SELECT 
				ROW_NUMBER()OVER (ORDER BY SRC.ProductBk, SRC._crda_ActiveFromDateTime) , 
				SRC.ProductBk , 
				SRC.[Name] , 			
				SRC.[Description] , 
				SRC.CurrencyIsoCode , 
				SRC.BusinessUnitSk , 		
				SRC.Sage200NominalAccount , 
				SRC.Sage50NominalAccount , 
				SRC.SageInstantNominalAccount , 
				SRC.IsActive , 
				SRC.IsAbstract , 
				SRC.IsPrimary , 
				SRC.IsRestricted , 
				SRC.AbstractionTypeBk , 
				SRC.ProductType , 		
				SRC.NavNominal , 
				SRC._crda_ActiveFromDateTime , 
				SRC._crda_ActiveToDateTime , 
				SRC._crda_Hash , 
				@_ExecutionId , 
				@_ExecutionId , 
				GETUTCDATE() , 
				GETUTCDATE() 
			FROM		#Source	SRC 
			ORDER BY SRC.ProductBk, SRC._crda_ActiveFromDateTime ; 

			/*Reassign lost FKs*/
			UPDATE	R 
			SET		BusinessUnitSk = ISNULL(K1.BusinessUnitSk , -1)
			FROM	dbo.DimProduct			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Product	HR	ON	HR.Id						= R.ProductBk
																	AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																	AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimBusinessUnit		K	ON	K.BusinessUnitSk = R.BusinessUnitSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Practice	RU	ON	RU.Id		= HR.KimbleOne__BusinessUnit__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimBusinessUnit	K1	ON	K1.BusinessUnitBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.BusinessUnitSk IS NULL ; 

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