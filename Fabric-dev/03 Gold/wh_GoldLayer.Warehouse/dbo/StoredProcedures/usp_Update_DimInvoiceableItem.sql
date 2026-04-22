CREATE   
	PROCEDURE dbo.usp_Update_DimInvoiceableItem
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimInvoiceableItem]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimInvoiceableItem]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimInvoiceableItem]')
	EXEC dbo.usp_Update_DimInvoiceableItem @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM [dbo].DimInvoiceableItem ORDER BY InvoiceableItemSk 
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

			TRUNCATE TABLE dbo.DimInvoiceableItem ; 

			INSERT INTO dbo.DimInvoiceableItem ( 
				InvoiceableItemSk, InvoiceableItemBk, [Name] , CurrencyIsoCode, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT 
				InvoiceableItemSk, InvoiceableItemBk, [Name] , CurrencyIsoCode, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord' , 'ZZZ', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
								InvoiceableItemSk, InvoiceableItemBk, [Name] , CurrencyIsoCode, 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimInvoiceableItem B 
				WHERE	B.InvoiceableItemSk = T.InvoiceableItemSk 
			) ; 

			SELECT	 
				  InvoiceableItemBk		= T.Id 
				, T.[Name]
				, T.CurrencyIsoCode
				, InvoiceItemAge			= T.KimbleOne__InvoiceItemAge__c
				, InvoiceableUsage			= T.KimbleOne__InvoiceableUsage__c
				, IsInternal				= T.KimbleOne__IsInternal__c
				, NirStatus					= IIF ( INV.Id IS NULL, 'Ready to Invoice', 'Awaiting Export' ) 
				, [Type]					= CASE WHEN T.KimbleOne__TimeEntry__c IS NULL 
												THEN (CASE 
														WHEN T.KimbleOne__TimeEntry__c IS NULL 
														THEN (	CASE 
																WHEN T.KimbleOne__RevenueAdjustment__c IS NULL 
																THEN  (	CASE 
																		WHEN T.KimbleOne__Milestone__c IS NULL 
																		THEN (	CASE 
																				WHEN T.KimbleOne__InvoiceAdjustment__c IS NULL 
																				THEN (	CASE 
																						WHEN T.KimbleOne__ExpenseItem__c IS NULL 
																						THEN 'Other' ELSE 'Expense' 
																					END ) ELSE 'InvAdj' 
																			END ) ELSE 'Milestone' 
																		END )
																ELSE 'RevAdj' 
															END ) ELSE 'PerRev' 
													END )  ELSE 'Time' 
												END 
				, OutboundInterfaceRunFg	= INV.OutboundInterfaceRunFg 
				,_crda_ActiveFromDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) 
				,_crda_ActiveToDateTime		= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime)
				,AD._crda_Hash 

			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_InvoiceableItem	T	
			LEFT JOIN	
					(
					SELECT  IV.Id
							,InvoiceableItemBk		= ILI.KimbleOne__InvoiceableItem__c 
							,OutboundInterfaceRunFg	= IIF(IV.KimbleOne__OutboundInterfaceRun__c IS NULL, 0, 1)
							,RN=ROW_NUMBER()
									OVER(
										PARTITION BY ILI.KimbleOne__InvoiceableItem__c 
										ORDER BY IV._crda_ActiveFromDateTime DESC
										)
					FROM lh_SilverLayer.Kantata.HISTORY_Invoice				IV

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_InvoiceLine	IL	ON	IV.Id =	IL.KimbleOne__Invoice__c 
																				AND	IL._crda_isDeleted			= 0 
																				AND	IL._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  

					LEFT JOIN lh_SilverLayer.Kantata.HISTORY_InvoiceLineItem	ILI	ON	ILI.KimbleOne__InvoiceLine__c	= IL.Id
																					AND ILI._crda_isDeleted			= 0 
																					AND	ILI._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
					WHERE	IV.KimbleOne__OutboundInterfaceRun__c IS NULL 
					AND		IV._crda_isDeleted			= 0 
					AND		IV._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
					AND		IV._crda_ActiveFromDateTime > @_Watermark  
					)			INV	ON	INV.InvoiceableItemBk	= T.Id 
									AND INV.RN = 1 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  T.[Name]	
							, T.CurrencyIsoCode	 
							, T.KimbleOne__InvoiceItemAge__c
							, T.KimbleOne__InvoiceableUsage__c	
							, T.KimbleOne__IsInternal__c 
							, IIF ( INV.Id IS NULL, 'Ready to Invoice', 'Awaiting Export' ) 
							, CASE WHEN T.KimbleOne__TimeEntry__c IS NULL 
								THEN (CASE 
										WHEN T.KimbleOne__TimeEntry__c IS NULL 
										THEN (	CASE 
												WHEN T.KimbleOne__RevenueAdjustment__c IS NULL 
												THEN  (	CASE 
														WHEN T.KimbleOne__Milestone__c IS NULL 
														THEN (	CASE 
																WHEN T.KimbleOne__InvoiceAdjustment__c IS NULL 
																THEN (	CASE 
																		WHEN T.KimbleOne__ExpenseItem__c IS NULL 
																		THEN 'Other' ELSE 'Expense' 
																	END ) ELSE 'InvAdj' 
															END ) ELSE 'Milestone' 
														END )
												ELSE 'RevAdj' 
											END ) ELSE 'PerRev' 
									END )  ELSE 'Time' 
								END
							, INV.OutboundInterfaceRunFg
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			--AND		(INV.Id IS NOT NULL) OR (T.KimbleOne__InvoiceableAmount__c <> 0 )
			AND		T._crda_isDeleted = 0 ; 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'InvoiceableItem';


			INSERT INTO dbo.DimInvoiceableItem
			(
				 InvoiceableItemSk 
				,InvoiceableItemBk
				,[Name]
				,InvoiceItemAge
				,InvoiceableUsage
				,CurrencyIsoCode
				,IsInternal
				,NirStatus
				,[Type] 
				,OutboundInterfaceRunFg

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
				 ROW_NUMBER()OVER (ORDER BY SRC.InvoiceableItemBk, SRC._crda_ActiveFromDateTime) 
				,SRC.InvoiceableItemBk
				,SRC.[Name]
				,SRC.InvoiceItemAge
				,SRC.InvoiceableUsage
				,SRC.CurrencyIsoCode
				,SRC.IsInternal
				,SRC.NirStatus
				,SRC.[Type]
				,SRC.OutboundInterfaceRunFg 

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
			ORDER BY SRC.InvoiceableItemBk, SRC._crda_ActiveFromDateTime ; 


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