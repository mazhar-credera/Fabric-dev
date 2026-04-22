CREATE  
	PROCEDURE dbo.usp_Update_DimResource
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResource]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResource]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimResource]')
	EXEC dbo.usp_Update_DimResource @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	--SELECT count(1), SUM(iif([ResourceManagerName] is not null, 1, 0)) , SUM(iif([Region] is not null, 1, 0)) , SUM(iif([TimePattern] is not null, 1, 0)) 
	SELECT * FROM dbo.DimResource ORDER BY ResourceSk 
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

			TRUNCATE TABLE dbo.DimResource ; 

			INSERT INTO dbo.DimResource ( 
				ResourceSk, ResourceBk, [Name], FirstName , LastName, OwnerSk, CurrencyIsoCode, ActualCost, UrlToKanataRecord, 
					ActualCostUnitType , BusinessUnitSk, StartDate, ContinuousServiceStart, Notes , GradeSk, PracticeSk, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT ResourceSk, ResourceBk, [Name], FirstName , LastName, OwnerSk, CurrencyIsoCode, ActualCost, UrlToKanataRecord, 
					ActualCostUnitType , BusinessUnitSk, StartDate, ContinuousServiceStart, Notes , GradeSk, PracticeSk, 
						_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
							,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord', '', '' , -1, 'ZZZ', 0, '', 
							'' , -1, '20000101', '20000101', '', -1, -1 ,
								'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
									,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	ResourceSk, ResourceBk, [Name], FirstName , LastName, OwnerSk, CurrencyIsoCode, ActualCost, UrlToKanataRecord, 
									ActualCostUnitType , BusinessUnitSk, StartDate, ContinuousServiceStart, Notes , GradeSk, PracticeSk, 
										_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
											,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimResource B 
				WHERE	B.ResourceSk = T.ResourceSk 
			) ; 


			SELECT	ResourceBk			= T.Id , 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime) , 
					[Name]				= IIF(CHARINDEX('(', T.[Name]) = 0, T.[Name], LEFT(T.[Name], CHARINDEX('(', T.[Name]) - 1)) ,
					FirstName			= ISNULL(T.KimbleOne__FirstName__c , '') , 
					LastName			= IIF(CHARINDEX('(', T.KimbleOne__LastName__c) = 0, T.KimbleOne__LastName__c, LEFT(T.KimbleOne__LastName__c, CHARINDEX('(', T.KimbleOne__LastName__c) - 1)) ,
					Email				= RU.Email , 
					LocationName		= LC.[Name] , 
					OwnerSk				= ISNULL(U.KimbleUserSk , -1 ) , 
					T.CurrencyIsoCode , 
					ActualCost			= ISNULL(T.KimbleOne__ActualCost__c , 0 ) , 
					ActualCostUnitType	= ISNULL(F.[Name] , '') , 

					BusinessUnitSk		= ISNULL(BU.BusinessUnitSk, -1) , 

					StartDate			= CAST(T.KimbleOne__StartDate__c AS DATE), 
					EndDate				= CAST(T.KimbleOne__EndDate__c AS DATE), 
					ContinuousServiceStart		= CAST(T.ContinuousServiceStart__c  AS DATE), 
					LatestP1AssignmentEndDate	= CAST(T.KimbleOne__LatestP1AssignmentEndDate__c  AS DATE), 
					Notes				= ISNULL(T.KC_CurrentSchedulingNotes__c, '') , 
					BillableFTE			=	
											CASE
												WHEN GR.[Name] LIKE 'Associate%' THEN 'Associates'
												WHEN GR.GradeShortName IN ('MC3', 'PR6', 'MC5', 'MC4', 'C1', 'F-STD', 'F-RET', 'E1', 'E2', 'E3', 'E4', 'E0') THEN 'FTEs (Billable)'
												ELSE 'Other'
											END , 

					GradeSk				= ISNULL(GR.GradeSk, -1) , 

					ResourceTypeBk		= RT.Id , 
					ResourceType		= RT.[Name] , 

					PracticeSk			= ISNULL(PR.PracticeSk, -1) , 
					ContractualBase		= ISNULL(C.[Name] , '') , 

					/*Screenings - Reference Datawarehouse.[Kimble].[vw_Resource1_Screening]*/
					MandatoryScreeningCompleted= IIF(T.DateLastMandatoryScreening__c > DATEADD(DAY,-90,GETUTCDATE()), 1, 0) ,
					DateScreeningDue	= CAST(T.DateScreeningDue__c AS DATE), 
					ScreeningStatus		= 	CASE
												WHEN T.DateLastMandatoryScreening__c > DATEADD(DAY,-90,GETUTCDATE()) THEN 1
												WHEN NOT(T.[DateLastMandatoryScreening__c] > DATEADD(DAY,-90,GETUTCDATE())) 
														AND T.DateScreeningDue__c < DATEADD(DAY,-2,CAST(GETUTCDATE() AS DATE)) THEN  -1
												ELSE 0
											END , 
					ScreeningDue		= IIF(ISNULL(T.DateScreeningDue__c,'19000101') < DATEADD(DAY,180,GETUTCDATE()), 1, 0 ) ,
					ScreeningOverdue	= IIF(ISNULL(T.DateScreeningDue__c,'19000101') > GETUTCDATE(), 0, 1 ) ,
					DateLastScreening	= CAST(T.DateLastScreening__c AS DATE),
					--Screenings
					/*RightToWork - Reference Datawarehouse.[Kimble].[vw_Resource1_RighttoWork]*/
					RightToWorkEndDate	= CAST(T.RightToWorkEndDate__c AS DATE),
					VisaStatus			= T.Visa_Status__c , 
					ActiveVisaType		= T.Active_Visa_Type__c , 
					VettingStatus		= IIF(DATEDIFF(MONTH,T.KimbleOne__StartDate__c,GETDATE()) > 12, 'Renewal', 'New Starter' ) , 
					RTWStatus			= 	CASE
												WHEN T.RightToWorkEndDate__c < DATEADD(DAY,30,GETUTCDATE()) THEN -1
												WHEN T.RightToWorkEndDate__c < DATEADD(DAY,90,GETUTCDATE()) THEN 0
												ELSE 1
											END , 
					ProvisionalEndDate	= CAST(T.Provisional_End_Date__c AS DATE),
					--RightToWork 
					AppraiserName		= LEFT(T.Appraiser__c, 80) , 
					ReasonForClose		= LEFT(T.ReasonForClose__c, 255) , 
					ResourceId			= LEFT(COALESCE(T.NAVResourceID__c, T.Resource_ID__c), 30) , 
					[Source]			= LEFT(T.Source__c, 255) , 
					ExperienceSummary	= LEFT(T.KC_ExperienceSummary__c, 255) , 
					Region				= LEFT(T.Region__c, 255) , 
					TimePattern			= LEFT(P.[Name], 255) , 

					_crda_Hash			= CAST(NULL AS VARBINARY(16)) , 
					RN					= ROW_NUMBER()
											OVER(
													PARTITION BY	T.Id 
													ORDER BY		T._crda_ActiveFromDateTime DESC
												) 
			INTO #Source 
			FROM		lh_SilverLayer.Kantata.HISTORY_Resource		T 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourceType	RT	ON	RT.Id						= T.KimbleOne__ResourceType__c 
														AND	T._crda_ActiveFromDateTime BETWEEN RT._crda_ActiveFromDateTime AND RT._crda_ActiveToDateTime
														AND	RT._crda_isDeleted			= 0 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_UnitType		F	ON	F.Id						= T.KimbleOne__ActualCostUnitType__c 
														AND	T._crda_ActiveFromDateTime BETWEEN F._crda_ActiveFromDateTime AND F._crda_ActiveToDateTime
														AND	F._crda_isDeleted			= 0  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_User			RU	ON	RU.Id						= T.KimbleOne__User__c 
														AND	T._crda_ActiveFromDateTime BETWEEN RU._crda_ActiveFromDateTime AND RU._crda_ActiveToDateTime 
														AND	RU._crda_isDeleted			= 0  

			LEFT JOIN	lh_SilverLayer.Kantata.History_ContractualBase C	ON	C.Id					= T.KC_ContractualBase__c  
															AND	T._crda_ActiveFromDateTime BETWEEN C._crda_ActiveFromDateTime AND C._crda_ActiveToDateTime 
															AND	C._crda_isDeleted		= 0  

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Location		LC	ON	LC.Id						= T.KimbleOne__Location__c   
														AND	T._crda_ActiveFromDateTime BETWEEN LC._crda_ActiveFromDateTime AND LC._crda_ActiveToDateTime 
														AND	LC._crda_isDeleted			= 0  

			LEFT JOIN  lh_SilverLayer.Kantata.HISTORY_TimePattern	P	ON	P.Id = T.KimbleOne__TimePattern__c 
														AND	T._crda_ActiveFromDateTime BETWEEN P._crda_ActiveFromDateTime AND P._crda_ActiveToDateTime 
														AND	P._crda_isDeleted			= 0  

			LEFT JOIN	dbo.DimKimbleUser			U	ON	U.KimbleUserBk		= T.OwnerId 
														AND	U.IsCurrent			= 1 
			LEFT JOIN	dbo.DimBusinessUnit			BU	ON	BU.BusinessUnitBk	= T.KimbleOne__BusinessUnit__c 
														AND	BU.IsCurrent		= 1 
			LEFT JOIN	dbo.DimGrade				GR	ON	GR.GradeBk			= T.KimbleOne__Grade__c 
														AND	GR.IsCurrent		= 1 
			LEFT JOIN	dbo.DimPractice				PR	ON	PR.PracticeBk		= T.KC_Practice__c 
														AND	PR.IsCurrent		= 1 

			WHERE	T._crda_ActiveFromDateTime	>= @_Watermark 
			AND		T._crda_isDeleted			= 0  
			ORDER BY T.Id, _crda_ActiveFromDateTime ; 


			UPDATE	R 
			SET		R._crda_Hash	= AD._crda_Hash 
			FROM	#Source	R 
			CROSS APPLY (
				SELECT 
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
								 [Name]		
								--,CONVERT(VARCHAR(35), _crda_ActiveToDateTime	, 121) /*Note*/
								,FirstName
								,LastName	
								,Email 
								,LocationName 
								,OwnerSk	
								,CurrencyIsoCode	
								,ActualCost
								,ActualCostUnitType
								,BusinessUnitSk
								,CONVERT(VARCHAR(35), StartDate	, 121)
								,CONVERT(VARCHAR(35), EndDate	, 121) 
								,CONVERT(VARCHAR(35),ContinuousServiceStart	, 121) 
								,CONVERT(VARCHAR(35), LatestP1AssignmentEndDate	, 121)
								,Notes	
								,BillableFTE
								,GradeSk 
								,ResourceTypeBk
								,PracticeSk 
								,ContractualBase 
								,MandatoryScreeningCompleted
								,CONVERT(VARCHAR(35), DateScreeningDue	, 121)
								,ScreeningStatus	
								,ScreeningDue	
								,ScreeningOverdue
								,CONVERT(VARCHAR(35), DateLastScreening	, 121)
								,CONVERT(VARCHAR(35), RightToWorkEndDate, 121)
								,VisaStatus			
								,ActiveVisaType		
								,VettingStatus		
								,RTWStatus			
								,CONVERT(VARCHAR(35), ProvisionalEndDate, 121)
								,AppraiserName 
								,ReasonForClose 
								,ResourceId 
								,[Source] 
								,ExperienceSummary 
								,Region 
								,TimePattern 
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD ; 
			/*SELECT '#Source', * FROM #Source*/


			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Resource';


			INSERT INTO dbo.DimResource(
				 ResourceSk 
				,ResourceBk
				,[Name]
				,FirstName
				,LastName
				,Email 
				,LocationName 
				,OwnerSk
				,CurrencyIsoCode
				,ActualCost
				,ActualCostUnitType
				,BusinessUnitSk
				,StartDate
				,EndDate
				,LatestP1AssignmentEndDate
				,ContinuousServiceStart 
				,Notes
				,LengthOfService 
				,BillableFTE
				,GradeSK
				,ResourceTypeBk
				,ResourceType
				,PracticeSk 
				,ContractualBase 
				,MandatoryScreeningCompleted
				,DateScreeningDue
				,ScreeningStatus
				,ScreeningDue
				,ScreeningOverdue
				,DateLastScreening
				,RightToWorkEndDate
				,VisaStatus
				,ActiveVisaType
				,VettingStatus
				,RTWStatus
				,ProvisionalEndDate 
				,AppraiserName 
				,ReasonForClose 
				,ResourceId 
				,[Source] 
				,ExperienceSummary 
				,Region 
				,TimePattern 
				,UrlToKanataRecord 

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
				 ROW_NUMBER()OVER (ORDER BY SRC.ResourceBk, SRC._crda_ActiveFromDateTime) 
				,SRC.ResourceBk
				,SRC.[Name]
				,SRC.FirstName
				,SRC.LastName
				,SRC.Email 
				,SRC.LocationName 
				,SRC.OwnerSk
				,SRC.CurrencyIsoCode
				,SRC.ActualCost
				,SRC.ActualCostUnitType
				,SRC.BusinessUnitSk
				,SRC.StartDate
				,SRC.EndDate
				,SRC.LatestP1AssignmentEndDate 
				,SRC.ContinuousServiceStart 
				,SRC.Notes
				,CONVERT([decimal](7,2),
						case
							when [ContinuousServiceStart]<[StartDate] 
								then (datediff(day,[ContinuousServiceStart],isnull([EndDate],getutcdate()))+(1))/(365.0) 
								else (datediff(day,[StartDate],isnull([EndDate],getutcdate()))+(1))/(365.0) 
							end)
				,SRC.BillableFTE
				,SRC.GradeSk
				,SRC.ResourceTypeBk
				,SRC.ResourceType
				,SRC.PracticeSk 
				,SRC.ContractualBase 
				,SRC.MandatoryScreeningCompleted
				,SRC.DateScreeningDue
				,SRC.ScreeningStatus
				,SRC.ScreeningDue
				,SRC.ScreeningOverdue
				,SRC.DateLastScreening
				,SRC.RightToWorkEndDate
				,SRC.VisaStatus
				,SRC.ActiveVisaType
				,SRC.VettingStatus
				,SRC.RTWStatus
				,SRC.ProvisionalEndDate 
				,SRC.AppraiserName 
				,SRC.ReasonForClose 
				,SRC.ResourceId 
				,SRC.[Source] 
				,SRC.ExperienceSummary 
				,SRC.Region 
				,SRC.TimePattern 
				,CONCAT('https://dmw.lightning.force.com/lightning/r/KimbleOne__Resource__c/',ResourceBk, '/view') 


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
			ORDER BY SRC.ResourceBk, SRC._crda_ActiveFromDateTime ; 


			UPDATE	R 
			SET 
				ResourceType	= ISNULL(RT.[Name], '') , 
				Email			= ISNULL(RU.Email, '') , 
				ReasonForClose	= LEFT(HR.ReasonForClose__c, 255) ,
				ResourceId		= LEFT(COALESCE(HR.NAVResourceID__c, HR.Resource_ID__c), 30) 
			FROM	dbo.DimResource			R 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id					= R.ResourceBk
																	AND	R._crda_ActiveFromDate BETWEEN HR._crda_ActiveFromDateTime AND HR._crda_ActiveToDateTime 
																	AND	HR._crda_isDeleted		= 0  
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourceType	RT	ON	RT.Id					= R.ResourceTypeBk 
																		AND	R._crda_ActiveFromDate BETWEEN RT._crda_ActiveFromDateTime AND RT._crda_ActiveToDateTime
																		AND	RT._crda_isDeleted		= 0  
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_User	RU	ON	RU.Id					= HR.KimbleOne__User__c 
																AND	RU._crda_ActiveToDateTime= '9999-12-31 23:59:59' 
																AND	RU._crda_isDeleted		= 0  ;

			UPDATE	R 
			SET 
				[Source]		= LEFT(HR.Source__c, 255) 
			FROM	dbo.DimResource			R 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id				= R.ResourceBk
																	AND	HR._crda_isDeleted	= 0  
																	AND	HR._crda_ActiveFromDateTime BETWEEN R._crda_ActiveFromDate AND R._crda_ActiveToDate
																	AND HR.Source__c IS NOT NULL ; 


			UPDATE	R 
			SET 
				ResourceManagerName		= LEFT(IIF(CHARINDEX('(', HR1.[Name]) = 0, HR1.[Name], LEFT(HR1.[Name], CHARINDEX('(', HR1.[Name]) - 1)), 80) 
			FROM	dbo.DimResource			R 
			INNER JOIN lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id				= R.ResourceBk
																	AND	HR._crda_isDeleted	= 0  
																	AND	HR._crda_ActiveFromDateTime = R._crda_ActiveFromDate
																	AND HR.KimbleOne__ResourceManager__c IS NOT NULL 
			LEFT JOIN lh_SilverLayer.Kantata.HISTORY_Resource	HR1	ON	HR1.Id				= HR.KimbleOne__ResourceManager__c
																	AND	HR1._crda_isDeleted	= 0  
																	AND	HR1._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  ; 



			/*Reassign lost FKs*/
			UPDATE	R 
			SET		OwnerSk = ISNULL(K1.KimbleUserSk , -1)
			FROM	dbo.DimResource			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id						= R.ResourceBk
																	AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																	AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimKimbleUser		K	ON	K.KimbleUserSk = R.OwnerSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_User	RU	ON	RU.Id						= HR.OwnerId 
																AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimKimbleUser		K1	ON	K1.KimbleUserBk = RU.Id 
												AND	K1.IsCurrent	= 1 

			WHERE	K.KimbleUserSk IS NULL ; 

			UPDATE	R 
			SET		BusinessUnitSk = ISNULL(K1.BusinessUnitSk , -1)
			FROM	dbo.DimResource			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id						= R.ResourceBk
																	AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																	AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimBusinessUnit		K	ON	K.BusinessUnitSk = R.BusinessUnitSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_BusinessUnit	RU	ON	RU.Id						= HR.KimbleOne__BusinessUnit__c 
																		AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																		AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimBusinessUnit		K1	ON	K1.BusinessUnitBk = RU.Id 
													AND	K1.IsCurrent	= 1 

			WHERE	K.BusinessUnitSk IS NULL ; 

			UPDATE	R 
			SET		GradeSk = ISNULL(K1.GradeSk , -1)
			FROM	dbo.DimResource			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id						= R.ResourceBk
																	AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																	AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimGrade		K	ON	K.GradeSk = R.GradeSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Grade	RU	ON	RU.Id						= HR.KimbleOne__Grade__c 
																AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimGrade		K1	ON	K1.GradeBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.GradeSk IS NULL ; 

			UPDATE	R 
			SET		PracticeSk = ISNULL(K1.PracticeSk , -1) 
			FROM	dbo.DimResource			R 
			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource	HR	ON	HR.Id						= R.ResourceBk
																	AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
																	AND	HR._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimPractice		K	ON	K.PracticeSk = R.PracticeSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Practice	RU	ON	RU.Id						= HR.KC_Practice__c 
																	AND	RU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'  
																	AND	RU._crda_isDeleted			= 0  

			LEFT JOIN dbo.DimPractice		K1	ON	K1.PracticeBk = RU.Id 
											AND	K1.IsCurrent	= 1 

			WHERE	K.PracticeSk IS NULL ; 


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