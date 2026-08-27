CREATE  
	PROCEDURE dbo.usp_Update_DimMilestone
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimMilestone]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimMilestone]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimMilestone]')
	EXEC dbo.usp_Update_DimMilestone @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT COUNT(1) FROM dbo.DimMilestone ; 
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

			TRUNCATE TABLE dbo.DimMilestone ; 

			INSERT INTO dbo.DimMilestone ( 
				MilestoneSk, MilestoneBk, MilestoneName , MilestoneDate, MilestoneDateSk, DaysFromToday, UrlToKanataPoRecord, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT 
				MilestoneSk, MilestoneBk, MilestoneName , MilestoneDate, MilestoneDateSk, DaysFromToday, UrlToKanataPoRecord, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord', '20000101', 20000101, 0, '', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
							MilestoneSk, MilestoneBk, MilestoneName , MilestoneDate, MilestoneDateSk, DaysFromToday, UrlToKanataPoRecord, 
								_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
									,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimMilestone B 
				WHERE	B.MilestoneSk = T.MilestoneSk 
			) ; 

			SELECT	
				 MilestoneBk			= M.Id 
				,_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), M._crda_ActiveFromDateTime) 
				,_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), M._crda_ActiveToDateTime) 
				,MilestoneName			= M.[Name] 
				,MilestoneDate			= CAST(M.KimbleOne__MilestoneDate__c  AS DATE)
				,BaselineMilestoneDate	= CAST(M.KimbleOne__BaselineMilestoneDate__c AS DATE)

				,MilestoneValue			= M.KimbleOne__MilestoneValue__c
				,SupplierInvoicingCurrencyMilestoneValue	= M.KimbleOne__SupplierInvoicingCurrencyMilestoneValue__c

				,M.CurrencyIsoCode
				,InvoicingCurrencyIsoCode			= M.KimbleOne__InvoicingCurrencyIsoCode__c
				,SupplierInvoicingCurrencyIsoCode	= M.KimbleOne__SupplierInvoicingCurrencyIsoCode__c

				,NavId					= M.NavId__c 
				,MilestoneDescription	= M.Type__c 
				,DeliveryElementBk		= M.KimbleOne__DeliveryElement__c 
				,MilestoneType			= MT.[Name]
				,MilestoneStatus		= MS.[Name]
				,_crda_Hash				= CAST(NULL AS VARBINARY(16)) 

			INTO #Source 
			FROM		lh_SilverLayer.Kantata.History_Milestone		M

			LEFT JOIN	lh_SilverLayer.Kantata.History_ReferenceData	MT	ON	MT.Id				= M.KimbleOne__MilestoneType__c 
															AND MT._crda_isDeleted	= 0 
															AND	MT._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			LEFT JOIN	lh_SilverLayer.Kantata.History_ReferenceData	MS	ON	MS.Id				= M.KimbleOne__MilestoneStatus__c 
															AND MS._crda_isDeleted	= 0 
															AND	MS._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

			WHERE	M._crda_ActiveFromDateTime > @_Watermark  
			AND		M._crda_isDeleted = 0 
			AND		M.KimbleOne__DeliveryElement__c	<> 'a0nD0000001yjIiIAI' ; 


			UPDATE	R 
			SET		R._crda_Hash	= AD._crda_Hash 
			FROM	#Source	R 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
						   MilestoneName
						  ,MilestoneDate
						  ,BaselineMilestoneDate
						  ,MilestoneValue
						  ,SupplierInvoicingCurrencyMilestoneValue
						  ,CurrencyIsoCode
						  ,InvoicingCurrencyIsoCode
						  ,SupplierInvoicingCurrencyIsoCode
						  ,NavId
						  ,MilestoneDescription
						  ,DeliveryElementBk
						  ,MilestoneType
						  ,MilestoneStatus
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD ; 


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Milestone';


			INSERT INTO dbo.DimMilestone
			(
				 MilestoneSk 
				,MilestoneBk
				,MilestoneName
				,MilestoneDate
				,MilestoneDateSk 
				,BaselineMilestoneDate
				,BaselineMilestoneDateSk
				,MilestoneValue
				,SupplierInvoicingCurrencyMilestoneValue
				,CurrencyIsoCode
				,InvoicingCurrencyIsoCode
				,SupplierInvoicingCurrencyIsoCode
				,NavId
				,MilestoneDescription
				,DeliveryElementBk
				,MilestoneType
				,MilestoneStatus
				,DaysFromToday
				,UrlToKanataPoRecord 

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
				 ROW_NUMBER()OVER (ORDER BY SRC.MilestoneBk, SRC._crda_ActiveFromDateTime) 
				,SRC.MilestoneBk
				,SRC.MilestoneName
				,SRC.MilestoneDate
				,CONVERT([int],CONVERT([varchar](8),MilestoneDate,(112))) 
				,SRC.BaselineMilestoneDate
				,CONVERT([int],CONVERT([varchar](8),BaselineMilestoneDate,(112))) 
				,SRC.MilestoneValue
				,SRC.SupplierInvoicingCurrencyMilestoneValue
				,SRC.CurrencyIsoCode
				,SRC.InvoicingCurrencyIsoCode
				,SRC.SupplierInvoicingCurrencyIsoCode
				,SRC.NavId
				,SRC.MilestoneDescription
				,SRC.DeliveryElementBk
				,SRC.MilestoneType
				,SRC.MilestoneStatus
				,DATEDIFF(DAY, CAST (GETUTCDATE() AS DATE), MilestoneDate) 
				,CONCAT('https://dmw.my.salesforce.com/', MilestoneBk) 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM	#Source	SRC 
			ORDER BY SRC.MilestoneBk, SRC._crda_ActiveFromDateTime ; 


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