CREATE  
	PROCEDURE dbo.usp_Update_FactSalesOpportunity
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , --not used
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	GroundhogDay Load 

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactSalesOpportunity]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactSalesOpportunity]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactSalesOpportunity]')
	EXEC dbo.usp_Update_FactSalesOpportunity @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM [dbo].[FactSalesOpportunity] ORDER BY SalesOpportunitySk;
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

			TRUNCATE TABLE dbo.FactSalesOpportunity ;


			SELECT	 SalesOpportunitySk		= SO.SalesOpportunitySk
					,AccountSk				= ISNULL(AC.AccountSk, -1) 
					,ProposalSk				= ISNULL(DP.ProposalSk, -1) 

					,SalesOpForecastStatusSk= ISNULL(FT.ForecastStatusSk, -1) 
					,PaForecastStatusSk		= ISNULL(FTP.ForecastStatusSk, -1) 

					,OpportunitySourceSk	= ISNULL(OPS.OpportunitySourceSk, -1) 
					,SectorSk				= ISNULL(SC.SectorSk, -1) 
					,AnalysisFactSk			= ISNULL(AF.AnalysisFactSk, -1) 
					,PaBusinessUnitSk		= ISNULL(BUP.BusinessUnitSk, -1) 

					,TotalRevenue			= SUM(SH.TotalRevenue)
					,WeightedRevenue		= SUM(SH.WeightedRevenue)
					,UnweightedRevenue		= SUM(SH.UnweightedRevenue)

			INTO #Source 
			FROM	lh_SilverLayer.Internal.salesopportunity	SH 
			INNER JOIN dbo.DimSalesOpportunity	SO	ON	SO.SalesOpportunityBk= SH.SalesOpportunityBk 
													AND	SO.IsCurrent		= 1 

			LEFT JOIN dbo.DimAccount			AC	ON	AC.AccountBk		= SH.AccountBk
													AND	AC.IsCurrent		= 1 

			LEFT JOIN dbo.DimProposal			DP	ON	DP.ProposalBk		= SH.ProposalBk
													AND	DP.IsCurrent		= 1 

			LEFT JOIN dbo.DimForecastStatus		FT	ON	FT.ForecastStatusBk	= SH.SalesOpForecastStatusBk 
													AND	FT.IsCurrent		= 1 
			LEFT JOIN dbo.DimForecastStatus		FTP	ON	FTP.ForecastStatusBk= SH.PaForecastStatusBk 
													AND	FTP.IsCurrent		= 1 

			LEFT JOIN dbo.DimAnalysisFact		AF	ON	AF.AnalysisFactBk		= SH.AnalysisFactBk
													AND	AF.IsCurrent			= 1 

			LEFT JOIN dbo.DimOpportunitySource	OPS	ON	OPS.OpportunitySourceBk = SH.OpportunitySourceBk 
													AND	OPS.IsCurrent			= 1 

			LEFT JOIN dbo.DimSector				SC	ON	SC.SectorBk				= SH.SectorBk 
													AND	SC.IsCurrent			= 1 

			LEFT JOIN dbo.DimBusinessUnit		BUP	ON	BUP.BusinessUnitBk		= SH.PaBusinessUnitBk 
													AND	BUP.IsCurrent			= 1 
			GROUP BY 													
				 SO.SalesOpportunitySk
				,ISNULL(AC.AccountSk, -1) 
				,ISNULL(DP.ProposalSk, -1) 

				,ISNULL(FT.ForecastStatusSk, -1) 
				,ISNULL(FTP.ForecastStatusSk, -1) 

				,ISNULL(OPS.OpportunitySourceSk, -1)
				,ISNULL(SC.SectorSk, -1) 
				,ISNULL(AF.AnalysisFactSk, -1) 
				,ISNULL(BUP.BusinessUnitSk, -1) ;


			INSERT INTO dbo.FactSalesOpportunity( 
				 FactSalesOpportunitySk 
				,SalesOpportunitySk 
				,AccountSk	
				,ProposalSk	

				,SalesOpForecastStatusSK
				,PaForecastStatusSk	

				,OpportunitySourceSk
				,SectorSk	
				,AnalysisFactSk	
				,PaBusinessUnitSk

				,TotalRevenue
				,WeightedRevenue	
				,UnweightedRevenue	

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY SRC.SalesOpportunitySk) 
				,SRC.SalesOpportunitySk
				,SRC.AccountSk	
				,SRC.ProposalSk	

				,SRC.SalesOpForecastStatusSk
				,SRC.PaForecastStatusSk

				,SRC.OpportunitySourceSk
				,SRC.SectorSk
				,SRC.AnalysisFactSk	
				,SRC.PaBusinessUnitSk

				,SRC.TotalRevenue	
				,SRC.WeightedRevenue
				,SRC.UnweightedRevenue
				,@_ExecutionId 
				,GETUTCDATE() 
			FROM	#Source	SRC 
			ORDER BY SRC.SalesOpportunitySk ; 


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