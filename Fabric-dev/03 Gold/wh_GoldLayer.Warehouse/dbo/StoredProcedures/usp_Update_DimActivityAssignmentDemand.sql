CREATE --OR ALTER
	PROCEDURE dbo.usp_Update_DimActivityAssignmentDemand
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimActivityAssignmentDemand]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimActivityAssignmentDemand]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimActivityAssignmentDemand]')
	EXEC dbo.usp_Update_DimActivityAssignmentDemand @ExecutionId = @LastExecId, @Watermark ='2025-06-01', @ProcessId=@ProcessId 
	SELECT COUNT(1) FROM dbo.DimActivityAssignmentDemand; --8460 
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

			TRUNCATE TABLE dbo.DimActivityAssignmentDemand ; 

			INSERT INTO dbo.DimActivityAssignmentDemand ( 
				ActivityAssignmentDemandSk, ActivityAssignmentDemandBk, [Name], ResourceSk, DeliveryGroupSk, ProposalSk, AccountSk, LocationSk
					,_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			SELECT ActivityAssignmentDemandSk, ActivityAssignmentDemandBk, [Name], ResourceSk, DeliveryGroupSk, ProposalSk, AccountSk, LocationSk
						,_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord' , -1, -1, -1, -1, -1
							,'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	ActivityAssignmentDemandSk, ActivityAssignmentDemandBk, [Name], ResourceSk, DeliveryGroupSk, ProposalSk, AccountSk, LocationSk
									,_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimActivityAssignmentDemand B 
				WHERE	B.ActivityAssignmentDemandSk = T.ActivityAssignmentDemandSk 
			) ; 


			SELECT 
				 ActivityAssignmentDemandBk	= T.Id
				,[Name]					= ISNULL(T.DisplayName__c , '') 
				,ResourceSk				= ISNULL(DR.ResourceSk, -1)
				,DeliveryGroupsk		= ISNULL(DDG.DeliveryGroupSk, -1)
				,Proposalsk				= ISNULL(DP.ProposalSk, -1) 
				,Accountsk				= ISNULL(DA.AccountSk, -1)
				,Locationsk				= ISNULL(DL.LocationSk, -1)

				,ActivityRole			= ISNULL(T.ActivityRole__c, '') 
				,T.CurrencyIsoCode
				,DemandRef				= T.Demand_Ref__c 
				,ForecastStatusName		= T.KC_ForecastStatus__c 
				,ProbabilityCode		= T.KimbleOne__ProbabilityCode__c 

				,StartDate				= T.KimbleOne__StartDate__c 
				,EndDate				= T.KimbleOne__EndDate__c 

				,T._crda_ActiveFromDateTime 
				,T._crda_ActiveToDateTime 
				,AD._crda_Hash 
			INTO	#Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand T 

			LEFT JOIN	dbo.DimResource						DR	ON	DR.ResourceBk	= T.KimbleOne__Resource__c 
																AND	DR.IsCurrent	= 1

			LEFT JOIN	dbo.DimProposal						DP	ON	DP.ProposalBk	= T.KimbleOne__Proposal__c 
																AND	DP.IsCurrent	= 1

			OUTER APPLY Internal.FN_ExtractKantataIdFromHtml(T.KimbleOne__DeliveryGroup__c, CHAR(177))	DG 
			OUTER APPLY Internal.FN_ExtractKantataIdFromHtml(T.KimbleOne__Location__c, CHAR(177))		LC 
			OUTER APPLY Internal.FN_ExtractKantataIdFromHtml(T.KimbleOne__Account__c, CHAR(177))		AC 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup		HDG	ON	HDG.TrimedId				= DG.ShortId 
																AND	HDG._crda_isDeleted = 0 
																AND	HDG._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimDeliveryGroup				DDG	ON	DDG.DeliveryGroupBK = HDG.Id 
																AND	DDG.IsCurrent		= 1

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Location				HLC	ON	HLC.TrimedId				= LC.ShortId 
																AND	HLC._crda_isDeleted = 0 
																AND	HLC._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimLocation						DL	ON	DL.LocationBk	= HLC.Id 
																AND	DL.IsCurrent	= 1

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account				HAC	ON	HAC.TrimedId				= AC.ShortId 
																AND	HAC._crda_isDeleted = 0 
																AND	HAC._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimAccount						DA	ON	DA.AccountBk	= HAC.Id 
																AND	DA.IsCurrent	= 1

			CROSS APPLY (
			SELECT
			CAST(HASHBYTES('MD5',
				CONCAT_WS('||',	
						  ISNULL(T.DisplayName__c ,'') 
						, ISNULL(DR.ResourceSk, -1)
						, ISNULL(DDG.DeliveryGroupSk, -1)
						, ISNULL(DP.ProposalSk, -1) 
						, ISNULL(DA.AccountSk, -1)
						, ISNULL(DL.LocationSk, -1)

						, ISNULL(T.ActivityRole__c, '') 
						, T.CurrencyIsoCode
						, T.Demand_Ref__c 
						, T.KC_ForecastStatus__c 
						, T.KimbleOne__ProbabilityCode__c 

						, CONVERT(VARCHAR(50), T.KimbleOne__StartDate__c, 121)
						, CONVERT(VARCHAR(50), T.KimbleOne__EndDate__c, 121)

					) 
				) AS VARBINARY(16)) AS _crda_Hash
			)  AD 
			WHERE	T._crda_ActiveFromDateTime	> @_Watermark 
			AND 	T._crda_isDeleted = 0 ; 


			--Realign History dates
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'ActivityAssignmentDemand';



			INSERT INTO dbo.DimActivityAssignmentDemand(
				  ActivityAssignmentDemandSk 
				, ActivityAssignmentDemandBk 
				, [Name]
				, ResourceSk
				, DeliveryGroupSk
				, ProposalSk
				, AccountSk
				, LocationSk
				, ActivityRole
				, CurrencyIsoCode
				, DemandRef
				, ForecastStatusName
				, ProbabilityCode
				, StartDate
				, EndDate
				, StartDateSk
				, EndDateSk

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
				  RN= ROW_NUMBER()OVER (PARTITION BY SRC.ActivityAssignmentDemandBk ORDER BY SRC._crda_ActiveFromDateTime)
				, SRC.ActivityAssignmentDemandBk 
				, SRC.[Name]
				, SRC.ResourceSk
				, SRC.DeliveryGroupSk
				, SRC.ProposalSk
				, SRC.AccountSk
				, SRC.LocationSk
				, SRC.ActivityRole
				, SRC.CurrencyIsoCode
				, SRC.DemandRef
				, SRC.ForecastStatusName
				, SRC.ProbabilityCode
				, SRC.StartDate
				, SRC.EndDate
				,(CONVERT([int],CONVERT([varchar](8),StartDate,(112))))
				,(CONVERT([int],CONVERT([varchar](8),EndDate,(112)))) 

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
			ORDER BY SRC.ActivityAssignmentDemandBk, SRC._crda_ActiveFromDateTime ; 



			UPDATE	A
			SET		A.ResourceSk = ISNULL(R.ResourceSk , -1)
			FROM		lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand	T 
			INNER JOIN	dbo.DimActivityAssignmentDemand			A	ON	A.ActivityAssignmentDemandBk = T.Id 
																	AND A.IsCurrent = 1
			INNER JOIN	dbo.DimResource			R	ON	R.ResourceBk = T.KimbleOne__Resource__c 
													AND	R.IsCurrent = 1
			WHERE	T._crda_ActiveToDateTime= '99991231'
			AND		T._crda_isDeleted = 0
			AND		R.ResourceSk <> A.ResourceSk ;


			/*Reassign lost FKs*/
			UPDATE	AD 
			SET		AccountSk = ISNULL(DA1.AccountSk , -1)
			--SELECT	AD.ActivityAssignmentDemandBk, AD.AccountSk, DA.AccountSk, DA1.AccountSk
			FROM	dbo.DimActivityAssignmentDemand				AD
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand	T	ON	T.Id = AD.ActivityAssignmentDemandBk
																	AND	T._crda_isDeleted = 0 
																	AND	T._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimAccount						DA	ON	DA.AccountSk	= AD.AccountSk
																--AND	DA.IsCurrent	= 1

			OUTER APPLY Internal.FN_ExtractKantataIdFromHtml(T.KimbleOne__Account__c, CHAR(177))		AC 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Account				HAC	ON	HAC.TrimedId				= AC.ShortId 
																AND	HAC._crda_isDeleted = 0 
																AND	HAC._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimAccount						DA1	ON	DA1.AccountBk	= HAC.Id 
																AND	DA1.IsCurrent	= 1
			WHERE	DA.AccountSk IS NULL 
			--AND		AD.IsCurrent = 1 ; 

			UPDATE	AD 
			SET		ResourceSk = ISNULL(R1.ResourceSk , -1)
			--SELECT	AD.ActivityAssignmentDemandBk, AD.ResourceSk, R.ResourceSk, R1.ResourceSk
			FROM	dbo.DimActivityAssignmentDemand				AD 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand	T	ON	T.Id = AD.ActivityAssignmentDemandBk
																	AND	T._crda_isDeleted = 0 
																	AND	T._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN dbo.DimResource			R	ON	R.ResourceSk = AD.ResourceSk  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id						= T.KimbleOne__Resource__c  
													AND	HR._crda_ActiveToDateTime	= '99991231' 
													AND	HR._crda_isDeleted = 0 

			LEFT JOIN dbo.DimResource			R1	ON	R1.ResourceSk	= HR.Id 
													AND	R1.IsCurrent	= 1 

			WHERE	R.ResourceSk IS NULL 
			AND		AD.IsCurrent = 1 ; 

			UPDATE	AD 
			SET		ProposalSk = ISNULL(P1.ProposalSk , -1)
			--SELECT	AD.ActivityAssignmentDemandBk, AD.ProposalSk, P.ProposalSk, P1.ProposalSk
			FROM	dbo.DimActivityAssignmentDemand				AD 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand	T	ON	T.Id = AD.ActivityAssignmentDemandBk
																	AND	T._crda_isDeleted = 0 
																	AND	T._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN dbo.DimProposal			P	ON	P.ProposalSk = AD.ProposalSk  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Proposal	HP	ON	HP.Id						= P.ProposalBk  
													AND	HP._crda_ActiveToDateTime	= '99991231' 
													AND	HP._crda_isDeleted = 0 

			LEFT JOIN dbo.DimProposal			P1	ON	P1.ProposalBk	= HP.Id 
													AND	P1.IsCurrent	= 1 

			WHERE	P.ProposalSk IS NULL 
			AND		AD.IsCurrent = 1 ; 


			UPDATE	AD 
			SET		LocationSK = ISNULL(DL1.LocationSK , -1)
			--SELECT	AD.ActivityAssignmentDemandBk, AD.LocationSk, DL.LocationSK, DL1.LocationSK
			FROM	dbo.DimActivityAssignmentDemand				AD
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand	T	ON	T.Id = AD.ActivityAssignmentDemandBk
																	AND	T._crda_isDeleted = 0 
																	AND	T._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimLocation						DL	ON	DL.LocationSK	= AD.LocationSK
																--AND	DA.IsCurrent	= 1

			OUTER APPLY Internal.FN_ExtractKantataIdFromHtml(T.KimbleOne__Location__c, CHAR(177))		AL 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Location				HAL	ON	HAL.TrimedId				= AL.ShortId 
																AND	HAL._crda_isDeleted = 0 
																AND	HAL._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimLocation						DL1	ON	DL1.LocationBK	= HAL.Id 
																AND	DL1.IsCurrent	= 1
			WHERE	DL.LocationSK IS NULL 
			AND		AD.IsCurrent = 1 ; 

			UPDATE	AD 
			SET		DeliveryGroupSk = ISNULL(DG1.DeliveryGroupSk , -1)
			--SELECT	AD.ActivityAssignmentDemandBk, AD.DeliveryGroupSK, DDG.DeliveryGroupSK, DG1.DeliveryGroupSK
			FROM	dbo.DimActivityAssignmentDemand				AD
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_ActivityAssignmentDemand	T	ON	T.Id = AD.ActivityAssignmentDemandBk
																	AND	T._crda_isDeleted = 0 
																	AND	T._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimDeliveryGroup				DDG	ON	DDG.DeliveryGroupSk	= AD.DeliveryGroupSk
																--AND	DA.IsCurrent	= 1

			OUTER APPLY Internal.FN_ExtractKantataIdFromHtml(T.KimbleOne__DeliveryGroup__c, CHAR(177))		DG 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup		HAG	ON	HAG.TrimedId				= DG.ShortId 
																AND	HAG._crda_isDeleted = 0 
																AND	HAG._crda_ActiveToDateTime	= '99991231' 

			LEFT JOIN	dbo.DimDeliveryGroup				DG1	ON	DG1.DeliveryGroupBK	= HAG.Id 
																AND	DG1.IsCurrent		= 1
			WHERE	DDG.DeliveryGroupSK IS NULL 
			AND		AD.IsCurrent = 1 ;

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