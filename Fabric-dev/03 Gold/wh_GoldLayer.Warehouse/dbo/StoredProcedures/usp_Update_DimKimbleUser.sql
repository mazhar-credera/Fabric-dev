CREATE  
	PROCEDURE dbo.usp_Update_DimKimbleUser
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS 
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimKimbleUser]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimKimbleUser]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimKimbleUser]')
	EXEC dbo.usp_Update_DimKimbleUser @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimKimbleUser ; 
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

			TRUNCATE TABLE dbo.DimKimbleUser ; 

			INSERT INTO dbo.DimKimbleUser ( 
				KimbleUserSk, KimbleUserBk, Username, FirstName, LastName, [Name], Title, Email, Alias, ProfileId, ManagerSk, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT KimbleUserSk, KimbleUserBk, Username, FirstName, LastName, [Name],  Title, Email, Alias, ProfileId, ManagerSk, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' , 'UnknownRecord', 'UnknownRecord', 'UnknownRecord', '', 'UnknownRecord', 'UnknownR', 'UnknownRecord', -1,
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	KimbleUserSk, KimbleUserBk, Username, FirstName, LastName, [Name], Title, Email, Alias, ProfileId, ManagerSk, 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimKimbleUser B 
				WHERE	B.KimbleUserSk = T.KimbleUserSk 
			) ; 


			SELECT	KimbleUserBk = T.Id , 
					T.Username , 
					FirstName	= ISNULL(T.FirstName , '') ,
					LastName	= ISNULL(T.LastName , '') , 
					[Name]		= CONCAT(ISNULL(T.FirstName , ''), ' ', ISNULL(T.LastName , '') ) , 
					Title		= ISNULL(T.Title , '') , 
					Email		= ISNULL(T.Email , '') ,
					Alias		= ISNULL(T.Alias , '') , 
					ProfileId	= ISNULL(T.ProfileId , '') ,
					ManagerId	= ISNULL(T.ManagerId , '') ,
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_User T
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.Username	
								, T.FirstName	
								, T.LastName	
								, T.Title
								, T.Email		
								, T.Alias		
								, T.ProfileId	
								, T.ManagerId	
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'KimbleUser';


			INSERT INTO dbo.DimKimbleUser
			( 
				KimbleUserSk , 
				KimbleUserBk , 
				Username , 
				FirstName , 
				LastName , 
				[Name] , 
				Title , 
				Email , 
				Alias , 
				ProfileId , 
				ManagerSk 

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
				ROW_NUMBER()OVER (PARTITION BY SRC.KimbleUserBk ORDER BY SRC._crda_ActiveFromDateTime) , 
				SRC.KimbleUserBk , 
				SRC.Username , 
				SRC.FirstName , 
				SRC.LastName , 
				SRC.[Name] , 
				SRC.Title , 
				SRC.Email , 	
				SRC.Alias , 	
				SRC.ProfileId , 
				-1 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM	#Source			SRC ;

			/*Update ManagerSk in dbo.DimKimbleUser*/
			;WITH cteManagerSk
			AS(
				SELECT	SrBk=S.KimbleUserBk, S.ManagerId, TgtBk=X.KimbleUserBk, TgtSk=X.KimbleUserSk
				FROM	#Source	S  
				LEFT JOIN (
					SELECT	K.KimbleUserSk, K.KimbleUserBk
					FROM	dbo.DimKimbleUser K 
					WHERE	K.IsCurrent = 1 
					GROUP BY K.KimbleUserSk, K.KimbleUserBk 
				) X	ON X.KimbleUserBk = S.ManagerId 
			) 
			UPDATE	KU 
			SET		KU.ManagerSk = ISNULL(TgtSk , -1)
			FROM	dbo.DimKimbleUser	KU 
			LEFT JOIN cteManagerSk		MK	ON	MK.SrBk = KU.KimbleUserBk ; 


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