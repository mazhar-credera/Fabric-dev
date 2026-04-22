CREATE   
	PROCEDURE dbo.usp_Update_DimSalesOpportunityHistory
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
WITH RECOMPILE 
AS

BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSalesOpportunityHistory]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSalesOpportunityHistory]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSalesOpportunityHistory]')
	EXEC dbo.usp_Update_DimSalesOpportunityHistory @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimSalesOpportunityHistory ;	--19281
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

			TRUNCATE TABLE dbo.DimSalesOpportunityHistory ; 

			DROP TABLE IF EXISTS #InitialValues 
			DROP TABLE IF EXISTS #Updates  
			DROP TABLE IF EXISTS #CleansedData 
			DROP TABLE IF EXISTS #Data 

			/*Get Initial Values*/ 
			SELECT
				X.OpportunityBk , 
				X.CreatedDate , 
				X.ForecastStatusBk 
			INTO #InitialValues 
			FROM(
				SELECT  OpportunityBk = S.Id , 
						ForecastStatusBk    = ISNULL(S.KimbleOne__ForecastStatus__c,'a0nD0000001yjIjIAI'), /*1. Lead (1%)*/
						CreatedDate = SystemModstamp , 
						RN	=	ROW_NUMBER()OVER
								(
									PARTITION BY Id 
									ORDER BY     SystemModstamp
								)
				FROM    lh_SilverLayer.Kantata.HISTORY_SalesOpportunity S 
				WHERE   S._crda_isDeleted  = 0 
				--WHERE S.Id = '006Px00000N9RwbIAF'
			) X 
			WHERE X.RN = 1 ; 

			INSERT INTO #InitialValues 
				(OpportunityBk, CreatedDate, ForecastStatusBk)
			SELECT
				X.OpportunityBk , 
				X.CreatedDate , 
				X.ForecastStatusBk 
			FROM(
				SELECT  OpportunityBk = S.Id , 
						/*ForecastStatusBk = F.Id , */
						ForecastStatusBk = ISNULL(F.Id, 'a0nD0000001yjIjIAI'), /*1. Lead (1%)*/
						CreatedDate = S.SystemModstamp , 
						RN	=	ROW_NUMBER()OVER
								(
									PARTITION BY S.Id 
									ORDER BY     S.SystemModstamp
								)
				FROM    lh_SilverLayer.Kantata.HISTORY_Opportunity S 
				LEFT JOIN	(
								SELECT	FS.Id, FS.[Name], 
										RN = ROW_NUMBER()OVER(PARTITION BY FS.[Name] ORDER BY FS._crda_ActiveToDateTime DESC )
								FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus FS
							)			F   ON  F.[Name] = S.[StageName] 
											AND	F.RN = 1 
											--AND F._crda_ActiveToDateTime = '90001231'
				WHERE   S._crda_isDeleted  = 0 
			) X 
			WHERE X.RN = 1 ; 



			/*Now any changes/updates since opp creation*/ 
			;WITH cteData
			AS(
				SELECT 
					 OpportunityBk  = S.OpportunityId
					,S.CreatedDate
					,ForecastStatusBk = F.Id
					,RN	=	ROW_NUMBER()OVER
							(
								PARTITION BY OpportunityId 
								ORDER BY     S.CreatedDate
							)
					,isl=	ROW_NUMBER()OVER
							(
								PARTITION BY OpportunityId ,  F.Id
								ORDER BY     S.CreatedDate
							)
				FROM    lh_SilverLayer.Kantata.HISTORY_OpportunityHistory S
				LEFT JOIN	(
								SELECT	FS.Id, FS.[Name], 
										RN = ROW_NUMBER()OVER(PARTITION BY FS.[Name] ORDER BY FS._crda_ActiveToDateTime DESC )
								FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus FS
							)			F   ON  F.[Name] = S.[StageName] 
											AND	F.RN = 1 
											--AND F._crda_ActiveToDateTime = '90001231'
				WHERE   S._crda_isDeleted  = 0  
				--AND	S.Id = '006Px00000N9RwbIAF'
			) 
			SELECT
				D.OpportunityBk, 
				CreatedDate     = MIN(D.CreatedDate) , 
				D.ForecastStatusBk 
			INTO #Updates 
			FROM    cteData D 
			GROUP BY
				D.OpportunityBk, 
				D.ForecastStatusBk , 
				RN-isl ; 

			INSERT INTO #Updates 
				(OpportunityBk, CreatedDate, ForecastStatusBk)
			SELECT 
				 OpportunityBk      = ParentId
				,CreatedDate
				--,ForecastStatusBk   = ISNULL(NewValue, 'a0nD0000001yjIjIAI') /*1. Lead (1%)*/
				,ForecastStatusBk   = NewValue 
			FROM    lh_SilverLayer.Kantata.HISTORY_SalesOpportunityHistory S 
			WHERE   _crda_isDeleted    = 0 
			AND     Field IN ('KimbleOne__ForecastStatus__c') 
			AND     DataType IN ('EntityId') 
			--AND	S.Id = '006Px00000N9RwbIAF'; 

			--SELECT * FROM #Updates

			/*Now delete any unchanged rows*/
			SELECT  X.OpportunityBk, X.CreatedDate, X.ForecastStatusBk , StageName = ISNULL(F.[Name] , '') , 
					NextStage=	LAG(ISNULL(F.[Name] , '')) 
									OVER	(	PARTITION BY	X.OpportunityBk
												ORDER BY		X.CreatedDate
											)  
			INTO #CleansedData 
			FROM( 
				SELECT  I.OpportunityBk, I.CreatedDate, I.ForecastStatusBk
				FROM    #InitialValues I 
				--WHERE OpportunityBk IN ('006Px00000E2yNtIAJ','006Px00000E2yNuIAJ')
				UNION ALL
				SELECT  U.OpportunityBk, U.CreatedDate, U.ForecastStatusBk 
				FROM    #Updates    U
				--WHERE OpportunityBk IN ('006Px00000E2yNtIAJ','006Px00000E2yNuIAJ')
			) X
			LEFT JOIN	(
							SELECT	FS.Id, FS.[Name], 
									RN = ROW_NUMBER()OVER(PARTITION BY FS.Id ORDER BY FS._crda_ActiveToDateTime DESC ) 
							FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus FS
						)			F   ON  F.Id = X.ForecastStatusBk 
										AND	F.RN = 1 ; 

			/*Delete no change records*/
			DELETE FROM #CleansedData WHERE StageName = NextStage ; 

			--SELECT * FROM #CleansedData

			SELECT  
				 X.OpportunityBk 
				,OpportunityCreatedDate = X.CreatedDate 
				,X.ForecastStatusBk 
				,CurrentStageName = ISNULL(F.[Name] , '') 
				,PrevStageBk = 
					LAG(ISNULL(X.ForecastStatusBk , '')) 
						OVER	(	PARTITION BY	X.OpportunityBk
									ORDER BY		X.CreatedDate
								) 
				,PreviousStageName = 
					LAG(ISNULL(F.[Name] , '')) 
						OVER	(	PARTITION BY	X.OpportunityBk
									ORDER BY		X.CreatedDate
								) 
				,LastStageChangeDate    = IIF(ISNULL(F.[Name] , '') <>
												LAG(ISNULL(F.[Name] , '')) 
													OVER	(	PARTITION BY	X.OpportunityBk
																ORDER BY		X.CreatedDate
															) 
												, X.CreatedDate, NULL 
											)
			INTO #Data 
			FROM( 
				SELECT  I.OpportunityBk, I.CreatedDate, I.ForecastStatusBk
				FROM    #CleansedData I 
			) X
			LEFT JOIN	(
							SELECT	FS.Id, FS.[Name], 
									RN = ROW_NUMBER()OVER(PARTITION BY FS.Id ORDER BY FS._crda_ActiveToDateTime DESC ) 
							FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus FS
						)			F   ON  F.Id = X.ForecastStatusBk 
										AND	F.RN = 1 
			ORDER BY X.OpportunityBk, X.CreatedDate ; 

			--SELECT * FROM #Data

				
			;WITH cteHistoryDates 
			AS (
					SELECT 
					d.*
					,CAST(d.OpportunityCreatedDate AS DATETIME) AS StartDateTime
					,LEAD(d.OpportunityCreatedDate)
						OVER (
							PARTITION BY d.OpportunityBk
							ORDER BY d.OpportunityCreatedDate
							) AS NextStart
					, LEAD(DATEADD(MILLISECOND, -3, CAST(d.OpportunityCreatedDate AS DATETIME)), 1, '9000-12-31') 
						OVER (
							PARTITION BY d.OpportunityBk 
							ORDER BY d.OpportunityCreatedDate
							) AS EndDateTime
					FROM #Data D 
			)
			INSERT INTO dbo.DimSalesOpportunityHistory
			( 
				 SalesOpportunitySk 
				,SalesOpportunityBk 
				,OpportunityCreatedDate 
				,OpportunityCreatedDateSk 
				,CurrentStageName
				,PreviousStageName
				,LastStageChangeDate

				,_crda_ActiveFromDate 
				,_crda_ActiveToDate 
				,_crda_ActiveFromDateSk 
				,_crda_ActiveToDateSk 
				,IsCurrent 
				,_crda_CreatedExecutionId  
				,_crda_CreatedDateTime 
				,_crda_isDeleted
			)
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY C.OpportunityBk, C.StartDateTime) 
				,C.OpportunityBk 
				,C.OpportunityCreatedDate 
				,(CONVERT([int],CONVERT([varchar](8),OpportunityCreatedDate,(112))))
				,C.CurrentStageName 
				,C.PreviousStageName 
				,C.LastStageChangeDate 

				,C.StartDateTime 
				,C.EndDateTime 
				,(CONVERT([int],CONVERT([varchar](8),StartDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),EndDateTime,(112)))) 
				,IIF( EndDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0


			FROM    cteHistoryDates C  
			ORDER BY C.OpportunityBk, C.StartDateTime 

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S.OpportunityCreatedDate), @_Watermark),121) FROM #Data S ;

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