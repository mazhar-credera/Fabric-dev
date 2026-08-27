CREATE  
	PROCEDURE dbo.usp_Update_FactResourceUsage
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	GroundhogDay Load  

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceUsage]' 
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceUsage]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactResourceUsage]')
	EXEC dbo.usp_Update_FactResourceUsage @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.FactResourceUsage ; 
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

			TRUNCATE TABLE dbo.FactResourceUsage ; 
			
			DROP TABLE IF EXISTS #Src ;

			SELECT	 ResourceSk				= RO.ResourceSk 
					,PA.PeriodStartDate
					,PA.PeriodEndDate	
					,AccountSk				= ISNULL(AC.AccountSk, -1) 
					,ResourcedActivityTypeSk= ISNULL(RT.ResourcedActivityTypeSk, -1) 
					,AnalysisFactSk			= AF.AnalysisFactSk 
					,DeliveryGroupSk		= ISNULL(DG.DeliveryGroupSk, -1) 
					,DmwActivityTypeSk		= ISNULL(DAT.DmwActivityTypeSk, -1) 
					,PaBusinessUnitSk		= ISNULL(PBU.BusinessUnitSk, -1) 

					,DeliveryElementSk		= ISNULL(DE.DeliveryElementSk, -1)
					,PracticeSk				= ISNULL(PR.PracticeSk, -1) 
					,GradeSk				= ISNULL(GR.GradeSk, -1) 

					,AccountBusinessUnitSk	= ISNULL(AB.BusinessUnitSk, -1) 
					,ResourceBusinessUnitSk	= ISNULL(RB.BusinessUnitSk, -1) 
					,ResourcedActivityNameSk= ISNULL(RAN.ResourcedActivityNameSk, -1)

					,P1ForecastAmount		= ISNULL(PA.P1ForecastAmount, 0)	
					,P2ForecastAmount		= ISNULL(PA.P2ForecastAmount, 0)	
					,P3ForecastAmount		= ISNULL(PA.P3ForecastAmount, 0)	

					,PA._crda_ActiveFromDateTime 

			INTO #Src 
			FROM	lh_SilverLayer.Internal.resourceusage			PA

			INNER JOIN dbo.DimAnalysisFact				AF	ON	AF.AnalysisFactBk		= PA.AnalysisFactBk
															AND	AF.IsCurrent			= 1 

			INNER JOIN dbo.DimResource					RO	ON	RO.ResourceBk			= PA.ResourceBk 
															AND	RO.IsCurrent			= 1 

			LEFT JOIN dbo.DimAccount					AC	ON	AC.AccountBk			= PA.AccountBk 
															AND	AC.IsCurrent			= 1 

			LEFT JOIN dbo.DimBusinessUnit				AB	ON	AB.BusinessUnitSk		= AC.BusinessUnitSk
															AND	AB.IsCurrent			= 1 

			LEFT JOIN dbo.DimBusinessUnit				RB	ON	RB.BusinessUnitBk		= PA.ResourceBusinessUnitBk
															AND	RB.IsCurrent			= 1 

			LEFT JOIN dbo.DimPractice					PR	ON	PR.PracticeBk			= PA.PracticeBk
															AND	PR.IsCurrent			= 1 

			LEFT JOIN dbo.DimDmwActivityType			DAT	ON	DAT.DmwActivityType		= PA.DmwActivityType

			LEFT JOIN dbo.DimResourcedActivityType		RT	ON	RT.ResourcedActivityTypeBk	= PA.ResourcedActivityTypeBk
															AND	RT.IsCurrent			= 1 

			LEFT JOIN dbo.DimResourcedActivityName		RAN	ON	RAN.ResourcedActivityName	= PA.ResourcedActivityDisplayName

			LEFT JOIN dbo.DimGrade						GR	ON	GR.GradeBk				= PA.GradeBk 
															AND	GR.IsCurrent			= 1 

			LEFT JOIN dbo.DimDeliveryGroup				DG	ON	DG.DeliveryGroupBk		= PA.DeliveryGroupBk
															AND	DG.IsCurrent			= 1 

			LEFT JOIN dbo.DimDeliveryElement			DE	ON	DE.DeliveryElementBk	= PA.DeliveryElementBk
															AND	DE.IsCurrent			= 1 

			LEFT JOIN dbo.DimBusinessUnit				PBU	ON	PBU.BusinessUnitBk		= PA.PaBusinessUnitBk
															AND	PBU.IsCurrent			= 1 ;


				
			INSERT INTO dbo.FactResourceUsage
			( 
				 FactResourceUsageSk 
				,ResourceSk
				,PeriodStartDate
				,PeriodEndDate 
				,PeriodStartSk 
				,PeriodEndSk 
				,AccountSk
				,AnalysisFactSk
				,ResourcedActivityTypeSk
				,DeliveryGroupSk
				,DeliveryElementSk
				,DmwActivityTypeSk
				,PaBusinessUnitSk

				,PracticeSk
				,GradeSk
				,AccountBusinessUnitSk
				,ResourceBusinessUnitSk
				,ResourcedActivityNameSk 

				,P1ForecastAmount
				,P2ForecastAmount
				,P3ForecastAmount

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY SRC.ResourceSk, SRC.PeriodStartDate, SRC.AccountSk) 
				,SRC.ResourceSk
				,SRC.PeriodStartDate
				,SRC.PeriodEndDate
				,(CONVERT([int],CONVERT([varchar](8),[PeriodStartDate],(112)))) 
				,(CONVERT([int],CONVERT([varchar](8),[PeriodEndDate],(112)))) 

				,SRC.AccountSk
				,SRC.AnalysisFactSk
				,SRC.ResourcedActivityTypeSk
				,SRC.DeliveryGroupSk
				,SRC.DeliveryElementSk
				,SRC.DmwActivityTypeSk
				,SRC.PaBusinessUnitSk

				,SRC.PracticeSk
				,SRC.GradeSk
				,SRC.AccountBusinessUnitSk
				,SRC.ResourceBusinessUnitSk
				,SRC.ResourcedActivityNameSk 

				,SRC.P1ForecastAmount
				,SRC.P2ForecastAmount
				,SRC.P3ForecastAmount

				,@_ExecutionId 
				,GETUTCDATE() 
			FROM  #Src	SRC
			ORDER BY 
				 SRC.ResourceSk
				,SRC.PeriodStartDate
				,SRC.PeriodEndDate
				,SRC.AccountSk ;
; 

			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Src S ;

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