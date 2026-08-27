CREATE  
	PROCEDURE dbo.usp_Update_DimContact
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimContact]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimContact]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimContact]')
	EXEC dbo.usp_Update_DimContact @ExecutionId = @LastExecId, @Watermark ='2025-06-01', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimContact ; 
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

			TRUNCATE TABLE dbo.DimContact ; 

			INSERT INTO dbo.DimContact ( 
				ContactSk, ContactBk, ContactType, ContactStatus, [Description], CurrencyIsoCode, FirstName, LastName, [Name] , 
					Department, CoreAssociate, Title, Salutation, OwnerSk, IsCurrentEmployee, AccountSk	, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT 
				ContactSk, ContactBk, ContactType, ContactStatus, [Description], CurrencyIsoCode, FirstName, LastName, [Name] , 
					Department, CoreAssociate, Title, Salutation, OwnerSk, IsCurrentEmployee, AccountSk	, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , '' , '', '' , 'ZZZ' , '' , '' , '' , 
							'' , '' , '' , '' , -1 , 0, -1 ,  
								'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
									,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
								ContactSk, ContactBk, ContactType, ContactStatus, [Description], CurrencyIsoCode, FirstName, LastName, [Name] , 
									Department, CoreAssociate, Title, Salutation, OwnerSk, IsCurrentEmployee, AccountSk	, 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimContact B 
				WHERE	B.ContactSk = T.ContactSk 
			) ; 


			SELECT	ContactBk		= T.Id , 
					ContactType		= ISNULL(T.Contact_Type__c , '') , 
					ContactStatus	= ISNULL(T.ContactStatus__c , '') , 
					[Description]	= ISNULL(LEFT(T.[Description],255),  '') , 
					T.CurrencyIsoCode , 
					FirstName		= ISNULL(T.FirstName, '') , 
					LastName		= ISNULL(T.LastName, '') , 
					[Name]			= ISNULL(T.[Name], '') , 
					Department		= ISNULL(T.Department , '') , 
					CoreAssociate	= ISNULL(T.CoreAssociate__c ,  '') , 
					Title			= ISNULL(LEFT(T.Title ,255),   '') , 
					Salutation		= ISNULL(T.Salutation ,  '') , 
					OwnerSk			= ISNULL(K.KimbleUserSk, -1) , 
					IsCurrentEmployee= ISNULL( T.OwnerIsCurrentEmployee__c , 0) , 
					AccountSk		= ISNULL(A.AccountSk , -1) , 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_Contact T 
			LEFT JOIN	dbo.DimKimbleUser	K	ON	K.KimbleUserBk = T.OwnerId
												AND	K.IsCurrent = 1 
			LEFT JOIN	dbo.DimAccount		A	ON	A.AccountBk = T.AccountId
												AND	A.IsCurrent = 1 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
						  T.Contact_Type__c	
						, T.ContactStatus__c	 
						, T.[Description]		
						, T.CurrencyIsoCode	
						, T.FirstName	
						, T.LastName	
						, T.[Name]		
						, T.Department	
						, T.CoreAssociate__c	
						, T.Title		
						, T.Salutation	
						, K.KimbleUserSk	 
						, T.OwnerIsCurrentEmployee__c	
						, A.AccountSk	 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 


			--Realign History dates
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Contact' ; 


			INSERT INTO dbo.DimContact(
				ContactSk ,
				ContactBk , 
				ContactType	, 
				ContactStatus ,
				[Description] , 
				CurrencyIsoCode , 
				FirstName , 
				LastName , 
				[Name] , 
				Department , 
				CoreAssociate , 
				Title , 
				Salutation , 
				OwnerSk , 
				IsCurrentEmployee , 
				AccountSk  

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
				RN= ROW_NUMBER()OVER (PARTITION BY SRC.ContactBk ORDER BY SRC._crda_ActiveFromDateTime) , 
				SRC.ContactBk , 
				SRC.ContactType	, 
				SRC.ContactStatus ,
				SRC.[Description] , 
				SRC.CurrencyIsoCode , 
				SRC.FirstName , 
				SRC.LastName , 
				SRC.[Name] , 
				SRC.Department , 
				SRC.CoreAssociate , 
				SRC.Title , 
				SRC.Salutation , 
				SRC.OwnerSk , 
				SRC.IsCurrentEmployee , 
				SRC.AccountSk , 

				 SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM		#Source		SRC 
			ORDER BY SRC.ContactBk, SRC._crda_ActiveFromDateTime ; 


			/*Reassign lost FKs*/
			UPDATE	AD 
			SET		AccountSk = ISNULL(P1.AccountSk , -1) 
			--SELECT	AD.ContactBk, AD.AccountSk, P.AccountSk, P1.AccountSk
			FROM	dbo.DimContact AD 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_Contact	T	ON	T.Id					= AD.ContactBk
																	AND	T._crda_isDeleted		= 0 
																	AND	T._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			LEFT JOIN dbo.DimAccount			P	ON	P.AccountSk = AD.AccountSk  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account	HP	ON	HP.Id						= T.AccountId   
																	AND	HP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	HP._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount			P1	ON	P1.AccountBk	= HP.Id 
													AND	P1.IsCurrent	= 1 

			WHERE	P.AccountSk IS NULL ; 

			UPDATE	AD 
			SET		OwnerSk = ISNULL(P1.KimbleUserSk , -1) 
			--SELECT	AD.ContactBk, AD.OwnerSk, P.KimbleUserSk, P1.KimbleUserSk
			FROM	dbo.DimContact AD 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_Contact	T	ON	T.Id					= AD.ContactBk
																	AND	T._crda_isDeleted		= 0 
																	AND	T._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

			LEFT JOIN dbo.DimKimbleUser			P	ON	P.KimbleUserSk = AD.OwnerSk  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_User	HP	ON	HP.Id						= T.OwnerId   
																AND	HP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																AND	HP._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimKimbleUser			P1	ON	P1.KimbleUserBk	= HP.Id 
													AND	P1.IsCurrent	= 1 

			WHERE	P.KimbleUserSk IS NULL 


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