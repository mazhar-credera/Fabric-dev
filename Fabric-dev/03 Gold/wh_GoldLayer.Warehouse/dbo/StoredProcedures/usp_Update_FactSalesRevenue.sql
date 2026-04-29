CREATE   
	PROCEDURE dbo.usp_Update_FactSalesRevenue
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
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactSalesRevenue]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactSalesRevenue]')
	DECLARE @ExecutionId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_FactSalesRevenue]')
	EXEC dbo.usp_Update_FactSalesRevenue @ExecutionId = @ExecutionId, @Watermark ='20000101', @ProcessId=@ProcessId 
	SELECT count(1) FROM [dbo].[FactSalesRevenue] ; 
	--SELECT * FROM [dbo].[FactSalesRevenue] ;	
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME2 = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;

	DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
	DECLARE	@DateInTwoYears	DATE = DATEADD(MONTH, 25, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

	-- GroundhogDay Load
	DECLARE @strNewWatermark	VARCHAR(35) =CONVERT(VARCHAR(35),@_Watermark,121),
			@strOldWatermark	VARCHAR(35) =CONVERT(VARCHAR(35),@_Watermark,121);


	BEGIN TRY

		BEGIN TRANSACTION 

			TRUNCATE TABLE dbo.FactSalesRevenue ;

			DROP TABLE IF EXISTS #Source ;

			SELECT	 
				 S.PeriodStartDate
				,S.PeriodEndDate 
				,S.FinancialReportingPeriodEnd 

				,AccountSk				= ISNULL(AC.AccountSk, -1)
				,PaBusinessUnitSk		= ISNULL(PBU.BusinessUnitSk, -1) 
				,ProposalSk				= ISNULL(PS.ProposalSk, -1)
				,SalesOpportunitySk		= ISNULL(SO.SalesOpportunitySk, -1)
				,ForecastStatusSk		= ISNULL(F.ForecastStatusSk, -1)
				,CurrencySk				= ISNULL(CU.CurrencySk, -1) 
				,AnalysisFactSk			= ISNULL(AF.AnalysisFactSk, -1)
				,AnalysisDimensionSk	= ISNULL(AD.AnalysisDimensionSk, -1)
				,DeliveryPracticeSk		= ISNULL(DP.PracticeSk, -1)
				,ResourceSk				= ISNULL(R.ResourceSk, -1) 
				,ResourcePracticeSk		= ISNULL(DR.PracticeSk, -1) 
				,PropositionSk			= ISNULL(PR.PropositionSk, -1) 

				,DeliveryGroupSk		= ISNULL(DG.DeliveryGroupSk, -1) 
				,DeliveryElementSk		= ISNULL(DE.DeliveryElementSk, -1) 
				,S.RevenueGenerationModel

				,ActualRevenue			= SUM(S.CorporateCurrencyActualRevenueCalc)
				,WeightedP1OnlyExcActual= SUM(S.WeightedP1OnlyExcActual)
				,WeightedP2Only			= SUM(S.WeightedP2Only)
				,WeightedP3Only			= SUM(S.WeightedP3Only)
				,WeightedRevenue		= SUM(
											CASE F.[Name]
												WHEN '1. Lead (1%)'			THEN CorporateCurrencyP3ForecastRevenueCalc	* (F.Probability * 0.01)	--P3
												WHEN '2. Qualify (10%)'		THEN CorporateCurrencyP3ForecastRevenueCalc	* (F.Probability * 0.01)	--P3		
												WHEN '3. Solutions (25%)'	THEN CorporateCurrencyP3ForecastRevenueCalc	* (F.Probability * 0.01)	--P3
												WHEN '4. Propose (50%)'		THEN CorporateCurrencyP3ForecastRevenueCalc	* (F.Probability * 0.01)	--P3
												WHEN '5. Negotiate (75%)'	THEN CorporateCurrencyP2ForecastRevenueCalc * (F.Probability * 0.01)	--P2
												WHEN '6. Verbal Win (90%)'	THEN CorporateCurrencyP2ForecastRevenueCalc	* (F.Probability * 0.01)	--P2
												WHEN '7. Firm (100%)'		THEN CorporateCurrencyP1ForecastRevenueCalc		--P1
												WHEN 'Working at Risk (100%)'THEN CorporateCurrencyP1ForecastRevenueCalc	--P1												
												ELSE 0
											END )
				,UnweightedRevenue		= SUM(
											CASE F.[Name]
												WHEN '1. Lead (1%)'			THEN CorporateCurrencyP3ForecastRevenueCalc	--P3
												WHEN '2. Qualify (10%)'		THEN CorporateCurrencyP3ForecastRevenueCalc	--P3
												WHEN '3. Solutions (25%)'	THEN CorporateCurrencyP3ForecastRevenueCalc	--P3
												WHEN '4. Propose (50%)'		THEN CorporateCurrencyP3ForecastRevenueCalc	--P3
												WHEN '5. Negotiate (75%)'	THEN CorporateCurrencyP2ForecastRevenueCalc  --P2
												WHEN '6. Verbal Win (90%)'	THEN CorporateCurrencyP2ForecastRevenueCalc	--P2
												WHEN '7. Firm (100%)'		THEN CorporateCurrencyP1ForecastRevenueCalc	--P1
												WHEN 'Working at Risk (100%)'THEN CorporateCurrencyP1ForecastRevenueCalc	--P1
												ELSE 0 
											END ) 

					,UnweightedP1OnlyExcActual	= SUM(IIF( CorporateCurrencyP1ForecastRevenueCalc <> CorporateCurrencyActualRevenueCalc , 
													(CorporateCurrencyP1ForecastRevenueCalc - CorporateCurrencyActualRevenueCalc) ,
													0 ) 
												) 

				,UnweightedP2Only			= SUM(IIF(CorporateCurrencyP1ForecastRevenueCalc = 0 , 
													CorporateCurrencyP2ForecastRevenueCalc , 
													0 ) 
												) 

				,UnweightedP3Only			= SUM(IIF(CorporateCurrencyP2ForecastRevenueCalc = 0 , 
													CorporateCurrencyP3ForecastRevenueCalc ,  
													0 ) 
												) 

				,FirmRevenue				= SUM(IIF(CorporateCurrencyP1ForecastRevenueCalc <> CorporateCurrencyActualRevenueCalc , 
													(CorporateCurrencyP1ForecastRevenueCalc - CorporateCurrencyActualRevenueCalc) , 
													0 ) 
												) 

				,RevenueSummary				= SUM(CASE S.ProbabilityCode
													WHEN 'P1' THEN S.CorporateCurrencyP1ForecastRevenueCalc
													WHEN 'P2' THEN S.WeightedP2Only
													WHEN 'P3' THEN S.WeightedP3Only
													ELSE 0  
												END ) 

				,CostSummary				= SUM(CASE
													WHEN S.CorporateCurrencyActualRevenueCalc > 0 THEN S.ActualCost
													WHEN S.ProbabilityCode = 'P1' THEN S.CorporateCurrencyP1ForecastCost 
													WHEN S.ProbabilityCode = 'P2' THEN S.CorporateCurrencyP2ForecastCost 
													WHEN S.ProbabilityCode = 'P3' THEN S.CorporateCurrencyP3ForecastCost 
													ELSE 0 
												END ) 

				, _crda_ActiveFromDateTime	= MAX(S._crda_ActiveFromDateTime) 

			INTO #Source 
			FROM	lh_SilverLayer.Internal.salesrevenue		S 

			LEFT JOIN	dbo.DimProposal			PS	ON	PS.ProposalBk		= S.ProposalBk  
													AND	PS.IsCurrent		= 1 

			LEFT JOIN	dbo.DimAccount			AC	ON	AC.AccountBk		= S.AccountBk 
													AND	AC.IsCurrent		= 1	

			LEFT JOIN	dbo.DimForecastStatus	F	ON	F.ForecastStatusBk	= S.ForecastStatusBk 
													AND	F.IsCurrent			= 1 
			
			LEFT JOIN	dbo.DimSalesOpportunity	SO	ON	SO.SalesOpportunityBk= S.SalesOpportunityBk 
													AND	SO.IsCurrent		= 1 
			
			LEFT JOIN	dbo.DimCurrency			CU	ON	CU.CurrencyBk		= S.CurrencyIsoCode 
													AND	CU.IsCurrent		= 1 
			
			LEFT JOIN	dbo.DimAnalysisDimension AD	ON	AD.AnalysisDimensionBk= S.AnalysisDimensionBk 
													AND	AD.IsCurrent		= 1 

			LEFT JOIN	dbo.DimAnalysisFact		AF	ON	AF.AnalysisFactBk	= S.AnalysisFactBk  
													AND	AF.IsCurrent		= 1 

			LEFT JOIN	dbo.DimResource			R	ON	R.ResourceBk= S.ResourceBk   
													AND	R.IsCurrent = 1 

			LEFT JOIN	dbo.DimPractice			DP	ON	DP.PracticeBk= S.DeliveryPracticeBk  
													AND	DP.IsCurrent = 1 

			LEFT JOIN	dbo.DimPractice			DR	ON	DR.PracticeBk= S.ResourcePracticeBk  
													AND	DR.IsCurrent = 1 

			LEFT JOIN	dbo.DimProposition		PR	ON	PR.PropositionBk= S.PropositionBk
													AND	PR.IsCurrent	= 1 

			LEFT JOIN	dbo.DimBusinessUnit		PBU	ON	PBU.BusinessUnitBk	= S.PaBusinessUnitBk
													AND	PBU.IsCurrent		= 1 

			LEFT JOIN	dbo.DimDeliveryGroup	DG	ON	DG.DeliveryGroupBk	= S.DeliveryGroupBk
													AND	DG.IsCurrent		= 1 

			LEFT JOIN	dbo.DimDeliveryElement	DE	ON	DE.DeliveryElementBk = S.DeliveryElementBk
													AND	DE.IsCurrent		= 1 

			WHERE	S._crda_ActiveFromDateTime	< @DateInTwoYears 
			AND		S.IsBalancingRecord			= 0 
			GROUP BY 
					 S.PeriodStartDate
					,S.PeriodEndDate 
					,S.FinancialReportingPeriodEnd 
					,ISNULL(AC.AccountSk, -1)
					,ISNULL(PBU.BusinessUnitSk, -1) 
					,ISNULL(PS.ProposalSk, -1)
					,ISNULL(SO.SalesOpportunitySk, -1)
					,ISNULL(F.ForecastStatusSk, -1)
					,ISNULL(CU.CurrencySk, -1) 
					,ISNULL(AD.AnalysisDimensionSk, -1)
					,ISNULL(AF.AnalysisFactSk, -1) 
					,ISNULL(DP.PracticeSk, -1)
					,ISNULL(R.ResourceSk, -1) 
					,ISNULL(DR.PracticeSk, -1) 
					,ISNULL(PR.PropositionSk, -1) 
					,ISNULL(DG.DeliveryGroupSk, -1) 
					,ISNULL(DE.DeliveryElementSk, -1) 
					,S.RevenueGenerationModel;


		
			INSERT INTO	dbo.FactSalesRevenue 
			(
				 FactSalesRevenueSk 
				,PeriodStartDate
				,PeriodEndDate 
				,PeriodStartDateSk  
				,PeriodEndDateSk 
				,FinancialReportingPeriodEndSk

				,AccountSk 
				,PaBusinessUnitSk  
				,ProposalSk
				,SalesOpportunitySk
				,ForecastStatusSk
				,CurrencySk
				,AnalysisDimensionSk
				,AnalysisFactSk 
				,DeliveryPracticeSk
				,ResourceSk 
				,ResourcePracticeSk
				,PropositionSk 
				,DeliveryGroupSk 
				,DeliveryElementSk 

				,ActualRevenue
				,WeightedP1OnlyExcActual
				,WeightedP2Only
				,WeightedP3Only
				,WeightedRevenue
				,UnweightedRevenue

				,UnweightedP1OnlyExcActual
				,UnweightedP2Only	
				,UnweightedP3Only	
				,FirmRevenue 
				,TotalRevenue 

				,WeightedP1_Actual			
				,WeightedP1_P2_Actual		
				,Weighted_P1_P2_P3_Actual	

				,RevenueSummary 
				,CostSummary 

				,RevenueGenerationModel
				,[_crda_FactSalesRevenueAccountTarget_JoinHash] 
				,[_crda_FactSalesRevenuePaBusinessUnitTarget_JoinHash] 
				,[_crda_FactSalesRevenuePaBusinessUnitAccountTarget_JoinHash] 

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT
				 ROW_NUMBER()OVER (ORDER BY S.PeriodStartDate, S.AccountSk, S.PaBusinessUnitSk, S._crda_ActiveFromDateTime) 
				,S.PeriodStartDate
				,S.PeriodEndDate 
				,(CONVERT([int],CONVERT([varchar](8),PeriodStartDate,(112))))
				,(CONVERT([int],CONVERT([varchar](8),PeriodEndDate,(112)))) 
				,(CONVERT([int],CONVERT([varchar](8),FinancialReportingPeriodEnd,(112)))) 

				,S.AccountSk
				,S.PaBusinessUnitSk  
				,S.ProposalSk
				,S.SalesOpportunitySk
				,S.ForecastStatusSk
				,S.CurrencySk
				,S.AnalysisDimensionSk 
				,S.AnalysisFactSk
				,S.DeliveryPracticeSk
				,S.ResourceSk 
				,S.ResourcePracticeSk
				,S.PropositionSk
				,S.DeliveryGroupSk 
				,S.DeliveryElementSk 

				,S.ActualRevenue
				,S.WeightedP1OnlyExcActual
				,S.WeightedP2Only
				,S.WeightedP3Only
				,S.WeightedRevenue
				,S.UnweightedRevenue

				,S.UnweightedP1OnlyExcActual
				,S.UnweightedP2Only	
				,S.UnweightedP3Only	
				,S.FirmRevenue 
				,((([ActualRevenue]+[FirmRevenue])+[WeightedP2Only])+[WeightedP3Only])

				,([ActualRevenue]+[WeightedP1OnlyExcActual]) 
				,(([ActualRevenue]+[WeightedP1OnlyExcActual])+[WeightedP2Only]) 
				,((([ActualRevenue]+[WeightedP1OnlyExcActual])+[WeightedP2Only])+[WeightedP3Only]) 

				,S.RevenueSummary 
				,S.CostSummary 

				,S.RevenueGenerationModel
				,(CONVERT([binary](16),hashbytes('MD5',concat_ws('||',PeriodStartDate,PeriodEndDate,AccountSk)))) 
				,(CONVERT([binary](16),hashbytes('MD5',concat_ws('||',PeriodStartDate,PeriodEndDate,PaBusinessUnitSk)))) 
				,(CONVERT([binary](16),hashbytes('MD5',concat_ws('||',PeriodStartDate,PeriodEnddate,AccountSk,PaBusinessUnitSk)))) 

				,@_ExecutionId
				,@TimeNow 
			FROM	#Source	S
			ORDER BY 
				 S.PeriodStartDate
				,S.PeriodEndDate 
				,S.AccountSk ;

		
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