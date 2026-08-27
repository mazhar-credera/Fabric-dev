CREATE  
	PROCEDURE dbo.usp_Update_DimDeliveryProgram
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryProgram]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryProgram]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimDeliveryProgram]')
	EXEC dbo.usp_Update_DimDeliveryProgram @ExecutionId = @LastExecId, @Watermark ='2025-06-01', @ProcessId=@ProcessId ; 
	SELECT * FROM dbo.DimDeliveryProgram; --631 
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

			TRUNCATE TABLE dbo.DimDeliveryElement ; 

			INSERT INTO dbo.DimDeliveryProgram ( 
				DeliveryProgramSk, DeliveryProgramBk, [Name], OwnerSk , AccountSk, CurrencyIsoCode, StatusSummaryTemplateInternal, RelatedDeliveryProgramSk, UrlToKanataRecord , 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT DeliveryProgramSk, DeliveryProgramBk, [Name], OwnerSk , AccountSk, CurrencyIsoCode, StatusSummaryTemplateInternal, RelatedDeliveryProgramSk, UrlToKanataRecord , 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord', -1, -1, 'ZZZ', '', -1, '', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	DeliveryProgramSk, DeliveryProgramBk, [Name], OwnerSk , AccountSk, CurrencyIsoCode, StatusSummaryTemplateInternal, RelatedDeliveryProgramSk, UrlToKanataRecord , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimDeliveryProgram B 
				WHERE	B.DeliveryProgramSk = T.DeliveryProgramSk 
			) ; 


			SELECT	DeliveryProgramBk= T.Id , 
					T.[Name], 
					T.OwnerId , 
					OwnerSk				= ISNULL(KU.KimbleUserSk , -1) , 
					T.KimbleOne__Account__c , 
					AccountSk			= ISNULL(AC.AccountSk , -1) , 
					T.CurrencyIsoCode , 
					StatusSummaryTemplateInternal	= ISNULL(T.KimbleOne__StatusSummaryTemplateInternal__c , '') , 
					RelatedDeliveryProgramBk = T.KimbleOne__DeliveryProgram__c , 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_DeliveryProgram	T 
			LEFT JOIN dbo.DimKimbleUser		KU	ON	KU.KimbleUserBk = T.OwnerId 
												AND	T._crda_ActiveFromDateTime BETWEEN KU._crda_ActiveFromDate AND KU._crda_ActiveToDate 
												--AND	KU.IsCurrent = 1 
			LEFT JOIN dbo.DimAccount		AC	ON	AC.AccountBk = T.KimbleOne__Account__c 
												AND	T._crda_ActiveFromDateTime BETWEEN AC._crda_ActiveFromDate AND AC._crda_ActiveToDate 
												--AND	AC.IsCurrent = 1 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								  T.[Name]		
								, T.OwnerId	 
								, T.KimbleOne__Account__c	
								, T.CurrencyIsoCode	
								, T.KimbleOne__StatusSummaryTemplateInternal__c	
								, T.KimbleOne__DeliveryProgram__c	
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark 
			AND		T._crda_isDeleted = 0 ; 

select * from #Source 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'DeliveryProgram';

			INSERT INTO dbo.DimDeliveryProgram
			( 
				DeliveryProgramSk , 
				DeliveryProgramBk , 
				[Name] , 
				OwnerSk , 
				AccountSk , 
				CurrencyIsoCode , 
				StatusSummaryTemplateInternal , 
				RelatedDeliveryProgramSk , 
				UrlToKanataRecord 

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
				ROW_NUMBER()OVER (PARTITION BY SRC.DeliveryProgramBk ORDER BY SRC._crda_ActiveFromDateTime) , 
				SRC.DeliveryProgramBk , 
				SRC.[Name] , 
				SRC.OwnerSk , 
				SRC.AccountSk , 
				SRC.CurrencyIsoCode , 
				SRC.StatusSummaryTemplateInternal , 
				-1 , 
				CONCAT('https://dmw.lightning.force.com/lightning/r/KimbleOne__DeliveryProgram__c/', DeliveryProgramBk, '/View') 

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



			/*Update RelatedDeliveryProgramSk in dbo.DimDeliveryProgram*/
			;WITH cteRelatedDeliveryProgramSk
			AS(
				SELECT	SrcBk=S.DeliveryProgramBk, SrcParentBk=S.DeliveryProgramBk, 
						TgtSk=X.DeliveryProgramSk, TgtBk=X.DeliveryProgramBk
				FROM	#Source	S  
				LEFT JOIN (
					SELECT	K.DeliveryProgramSk, K.DeliveryProgramBk
					FROM	dbo.DimDeliveryProgram K 
					WHERE	K.IsCurrent = 1 
					GROUP BY K.DeliveryProgramSk, K.DeliveryProgramBk 
				) X	ON X.DeliveryProgramBk = S.RelatedDeliveryProgramBk 
			) 
			UPDATE	KU 
			SET		KU.RelatedDeliveryProgramSk = ISNULL(TgtSk , -1)
			FROM	dbo.DimDeliveryProgram		KU 
			INNER JOIN cteRelatedDeliveryProgramSk	MK	ON	MK.SrcBk = KU.DeliveryProgramBk ; 


			/*Reassign lost FKs*/
			UPDATE	R 
			SET		OwnerSk = K1.KimbleUserSk 
			FROM	dbo.DimDeliveryProgram			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryProgram	HR	ON	HR.Id				= R.DeliveryProgramBk
															AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
															AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimKimbleUser		K	ON	K.KimbleUserSk = R.OwnerSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_User	RU	ON	RU.Id						= HR.OwnerId 
												AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
												AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimKimbleUser	K1	ON	K1.KimbleUserBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.KimbleUserSk IS NULL ; 
			--AND		R.IsCurrent = 1 ; 

			UPDATE	R 
			SET		AccountSk = K1.AccountSk 
	--		SELECT		R.AccountSk , K1.AccountSk , K.AccountSk
			FROM	dbo.DimDeliveryProgram			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryProgram	HR	ON	HR.Id				= R.DeliveryProgramBk
															AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
															AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount		K	ON	K.AccountSk = R.AccountSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account	RU	ON	RU.Id						= HR.KimbleOne__Account__c
													AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
													AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimAccount	K1	ON	K1.AccountBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.AccountSk IS NULL ; 

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