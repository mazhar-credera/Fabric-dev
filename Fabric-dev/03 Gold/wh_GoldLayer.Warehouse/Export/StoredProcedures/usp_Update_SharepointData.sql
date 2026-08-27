CREATE   
	PROCEDURE Export.usp_Update_SharepointData 
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 

AS
BEGIN 
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	/*Groundhogday Load*/

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Export].[usp_Update_SharepointData]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Export].[usp_Update_SharepointData]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Export].[usp_Update_SharepointData]')
	EXEC Export.usp_Update_SharepointData @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM Export.SharepointData ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 

	DECLARE @strNewWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			TRUNCATE TABLE Export.SharepointData ; 
			
			WITH 
			CTE_Competencies
			AS(
				SELECT	 R.ResourceBk			AS ResourceId		
						,R.[Name]				AS Crederian		
						,CG.[Name]				AS CapabilityGroup 
						,STRING_AGG
								( 
									CONCAT	
									( 
										CHAR(34), ISNULL(CAST(CT.[Name] AS NVARCHAR(MAX)), ' '), CHAR(34)
									) , ','	
								)	
								WITHIN GROUP ( ORDER BY CT.[Name] ASC)		AS Competency	

				FROM		dbo.DimResource						R 
				INNER JOIN	lh_SilverLayer.Kantata.HISTORY_ResourceCapability	RC	ON	RC.KimbleOne__Resource__c = R.ResourceBk 
																					AND	RC._crda_isDeleted = 0 
																					AND	RC._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

				LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_CapabilityType		CT	ON	CT.Id		= RC.KimbleOne__CapabilityType__c
																					AND	CT._crda_isDeleted = 0 
																					AND	CT._crda_ActiveToDateTime = '9999-12-31 23:59:59' 

				LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_CapabilityGroup		CG	ON	CG.Id		= CT.KimbleOne__CapabilityGroup__c 
																					AND	CG._crda_isDeleted = 0 
																					AND	CG._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
				WHERE	R.IsCurrent = 1
				AND		(R.[Name] NOT LIKE '%#%' AND  R.[Name] NOT LIKE '%@%')
				AND		R.EndDate IS NULL	
				GROUP BY	R.ResourceBk,
							R.[Name],
							CG.[Name] 
			), 
			CTE_Assignment 
			AS(
				SELECT	X.ResourceId ,
						Account				=	STRING_AGG(
													ISNULL(CAST(X.[AccountName] AS NVARCHAR(MAX)), ' '),
													', ')
											WITHIN GROUP ( ORDER BY X.[DemandStart] ASC) , 
						ResourceActivity	=	STRING_AGG(
													CONCAT(CHAR(34), 
														ISNULL(CAST(X.[ActivityName] AS NVARCHAR(MAX)), ' ')
														, CHAR(34))
													, ', ')	
												WITHIN GROUP ( ORDER BY X.[DemandStart] ASC) , 
						AccountURL			=	STRING_AGG(
													CONCAT(CHAR(34), 
														ISNULL(CAST(CONCAT('https://dmw.my.salesforce.com/',X.AccountId) AS NVARCHAR(MAX)), ' ')
														, CHAR(34))
													, ', ')
												WITHIN GROUP ( ORDER BY X.[DemandStart] ASC) , 
						LatestCurrentAssignmentEndDate = MAX(X.[DemandEnd])
				FROM(
					SELECT	ResourceId = B.ResourceBk, AccountName = DA.[Name], AccountId= DA.AccountBk ,
							[DemandStart]=B.PeriodStartDate, [DemandEnd]=B.PeriodEndDate,
							ActivityName	= ISNULL(RA.KimbleOne__FullName__c, DG.[Name])

					FROM	lh_SilverLayer.Internal.demandcapacity		B

					LEFT JOIN	dbo.DimAccount			DA	ON	DA.AccountBk		= B.DeliveryGroupAccountBk 
															AND DA.IsCurrent	= 1

					LEFT JOIN	dbo.DimDeliveryGroup	DG	ON	DG.DeliveryGroupBk	= B.ActivityDeliveryGroupBk 
															AND DG.IsCurrent	= 1

					LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity
															RA  ON  RA.Id				= B.ResourcedActivityBk
																AND	RA._crda_isDeleted = 0 
																AND	RA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 


					WHERE	B.DemandCapacityType IN ('CURRENTrole') 
					--AND		B.ResourceBk = 'a1X4K000000JV6aUAG' 
					AND		B.PeriodEndDate >= CAST(GETUTCDATE() as DATE) 
				) X 
				GROUP BY X.ResourceId 
			) 
			INSERT INTO Export.SharepointData
			(
				 Crederian
				,Grade
				,IsFeeEarning
				,CrederanStartDate
				,CrederanEndDate
				,ResourceType
				,EmailAddress
				,ResourceBu
				,InternalAlignment
				,Competencies
				,Account
				,CurerntClientAssignment
				,LatestCurrentAssignmentEndDate
				,InternalRoles
				,Certifications
				,Propositions
				,CareerCoach
				,Summary
				,ResourceURL
				,AccountURL 

			)
			SELECT	
				 Crederian			= R.[Name] 
				,Grade				= G.[Name] 
				,IsFeeEarning		= G.IsFeeEarning 
				,CrederanStartDate	= R.StartDate 
				,CrederanEndDate	= R.EndDate 
				,ResourceType		= R.ResourceType 
				,EmailAddress		= C.Email 
				,ResourceBU			= BU.BusinessUnitName 
				,InternalAlignment	= P.[PracticeName] 
				,Competencies		= LEFT(CC.Competency, 8000) 
				,Account			= LEFT(CA.Account, 4000)
				,CurerntClientAssignment	= LEFT(CA.ResourceActivity, 8000)
				,CA.LatestCurrentAssignmentEndDate
				,InternalRoles		= LEFT(
										IIF
											( HR.Pillar_Alignment__c IS NOT NULL, 
												CONCAT(CHAR(34), REPLACE(HR.Pillar_Alignment__c,';','","'), CHAR(34)), 
													HR.Pillar_Alignment__c 
											) 
										, 8000)
				,Certifications		= LEFT(Crt.Competency, 8000)
				,Propositions		= LEFT(Prp.Competency, 8000)
				,CareerCoach		= R.AppraiserName	
				,Summary			= LEFT(R.ExperienceSummary, 8000) 
				,ResourceURL		= R.UrlToKanataRecord 
				,AccountURL			= LEFT(CA.AccountURL, 8000) 

			FROM		dbo.DimResource			R 

			INNER JOIN	lh_SilverLayer.Kantata.HISTORY_Resource
												HR	ON	HR.Id = R.ResourceBk 

			LEFT JOIN	dbo.DimGrade			G	ON	G.GradeSk = R.GradeSk 

			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Contact	
												C	ON	C.Id	= HR.KimbleOne__Contact__c 

			LEFT JOIN	dbo.DimPractice			P	ON	P.PracticeSk	= R.PracticeSk 

			LEFT JOIN	dbo.DimBusinessUnit		BU	ON	BU.BusinessUnitSk = R.BusinessUnitSk 

			LEFT JOIN	CTE_Assignment			CA	ON	CA.ResourceId = R.ResourceBk

			LEFT JOIN	CTE_Competencies		CC	ON	CC.ResourceId		= R.ResourceBk 
													AND CC.CapabilityGroup	= '1. Current Capabilities'

			LEFT JOIN	CTE_Competencies		Prp	ON	Prp.ResourceId		= R.ResourceBk 
													AND Prp.CapabilityGroup = '7. Propositions'

			LEFT JOIN	CTE_Competencies		Crt ON	Crt.ResourceId		= R.ResourceBk 
													AND Crt.CapabilityGroup = '8. Certifications' 

			WHERE	R.IsCurrent = 1

			AND		(
						(R.[Name] NOT LIKE '%#%' AND  R.[Name] NOT LIKE '%@%')
						AND R.ResourceType NOT IN ('Resource Group')
						AND	R.StartDate <= GETUTCDATE()
					) 
			--AND		R.ResourceBk = 'a1X3z000004T6ZzEAK'


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