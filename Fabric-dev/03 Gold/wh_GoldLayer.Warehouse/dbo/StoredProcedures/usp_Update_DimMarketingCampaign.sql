CREATE  
	PROCEDURE dbo.usp_Update_DimMarketingCampaign
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimMarketingCampaign]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimMarketingCampaign]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimMarketingCampaign]')
	EXEC dbo.usp_Update_DimMarketingCampaign @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT count(1) FROM dbo.DimMarketingCampaign ;
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

			TRUNCATE TABLE dbo.DimMarketingCampaign ; 

			INSERT INTO dbo.DimMarketingCampaign ( 
				MarketingCampaignSk, MarketingCampaignBk, [Name], [Type], [Status], OwnerSk , 
					CurrencyIsoCode, ActualCost, StartDate, EndDate, ParentMarketingCampaignSk , 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT MarketingCampaignSk, MarketingCampaignBk, [Name], [Type], [Status], OwnerSk, 
						CurrencyIsoCode, ActualCost, StartDate, EndDate, ParentMarketingCampaignSk , 
							_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
								,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , 'UnknownRecord' , 'UnknownRecord', 'UnknownRecord', -1, 'ZZZ', 0, '20000101', '20000101', -1 , 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	MarketingCampaignSk, MarketingCampaignBk, [Name], [Type], [Status], OwnerSk, 
									CurrencyIsoCode, ActualCost, StartDate, EndDate, ParentMarketingCampaignSk , 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimMarketingCampaign B 
				WHERE	B.MarketingCampaignSk = T.MarketingCampaignSk 
			) ; 

			SELECT	MarketingCampaignBk= T.Id , 
					T.[Name], 
					[Type]		= ISNULL(T.KimbleOne__Type__c, '') , 
					[Status]	= ISNULL(T.Status__c, '') , 
					T.OwnerId , 
					OwnerSk		= ISNULL(KU.KimbleUserSk , -1 ) , 
					T.CurrencyIsoCode , 
					ActualCost	= ISNULL(T.KimbleOne__ActualCost__c , 0) ,
					StartDate	= CONVERT(DATE, T.KimbleOne__StartDate__c) , 
					EndDate		= CONVERT(DATE, T.KimbleOne__EndDate__c) , 
					ParentMarketingCampaignBk = T.ParentMarketingCampaign__c , 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_MarketingCampaign	T 
			LEFT JOIN dbo.DimKimbleUser		KU	ON	KU.KimbleUserBk = T.OwnerId 
												AND	KU.IsCurrent = 1
			CROSS APPLY (
			SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  T.[Name]	
							, T.KimbleOne__Type__c	
							, T.Status__c
							, T.OwnerId	
							, T.CurrencyIsoCode
							, T.KimbleOne__ActualCost__c
							, CONVERT(VARCHAR(35),T.KimbleOne__StartDate__c, 121)
							, CONVERT(VARCHAR(35),T.KimbleOne__EndDate__c, 121)
							, T.ParentMarketingCampaign__c
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark 
			AND		T._crda_isDeleted = 0 ; 


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'MarketingCampaign';

			INSERT INTO dbo.DimMarketingCampaign(
				MarketingCampaignSk , 
				MarketingCampaignBk , 
				[Name] , 
				[Type] , 
				[Status] , 
				OwnerSk , 
				CurrencyIsoCode , 
				ActualCost , 
				StartDate , 
				EndDate 

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
				ROW_NUMBER()OVER (ORDER BY SRC.MarketingCampaignBk, SRC._crda_ActiveFromDateTime) , 
				SRC.MarketingCampaignBk , 
				SRC.[Name] , 
				SRC.[Type] , 
				SRC.[Status] , 
				SRC.OwnerSk , 
				SRC.CurrencyIsoCode , 
				SRC.ActualCost , 
				SRC.StartDate , 
				SRC.EndDate 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM		#Source	SRC 
			ORDER BY SRC.MarketingCampaignBk, SRC._crda_ActiveFromDateTime ; 

			/*Update ParentMarketingCampaignSk in dbo.DimMarketingCampaign*/
			;WITH cteManagerSk
			AS(
				SELECT	SrcBk=S.MarketingCampaignBk, SrcParentBk=S.ParentMarketingCampaignBk, 
						TgtSk=X.MarketingCampaignSk, TgtBk=X.MarketingCampaignBk
				FROM	#Updates	S  
				LEFT JOIN (
					SELECT	K.MarketingCampaignSk, K.MarketingCampaignBk
					FROM	dbo.DimMarketingCampaign K 
					WHERE	K.IsCurrent = 1 
					GROUP BY K.MarketingCampaignSk, K.MarketingCampaignBk 
				) X	ON X.MarketingCampaignBk = S.ParentMarketingCampaignBk 
			) 
			UPDATE	KU 
			SET		KU.ParentMarketingCampaignSk = ISNULL(TgtSk , -1)
			FROM	dbo.DimMarketingCampaign	KU 
			INNER JOIN cteManagerSk		MK	ON	MK.SrcBk = KU.MarketingCampaignBk ; 


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