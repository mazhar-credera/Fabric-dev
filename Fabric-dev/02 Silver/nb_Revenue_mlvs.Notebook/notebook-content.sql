-- Fabric notebook source

-- METADATA ********************

-- META {
-- META   "kernel_info": {
-- META     "name": "synapse_pyspark"
-- META   },
-- META   "dependencies": {
-- META     "lakehouse": {
-- META       "default_lakehouse": "3231059f-0365-4fa8-81bc-a7ed8c6ad211",
-- META       "default_lakehouse_name": "lh_SilverLayer",
-- META       "default_lakehouse_workspace_id": "29f8113f-2a90-401e-a4f7-d6121b481419",
-- META       "known_lakehouses": [
-- META         {
-- META           "id": "3231059f-0365-4fa8-81bc-a7ed8c6ad211"
-- META         }
-- META       ]
-- META     }
-- META   }
-- META }

-- MARKDOWN ********************

-- # Create materialized lake views 
-- 1. Use this notebook to create materialized lake views. 
-- 2. Select **Run all** to run the notebook. 
-- 3. When the notebook run is completed, return to your lakehouse and refresh your materialized lake views graph. 


-- CELL ********************

-- Welcome to your new notebook 
-- Type here in the cell editor to add code! 
CREATE SCHEMA IF NOT EXISTS Internal;


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- Enable change data feed (CDF) on the source tables so that optimal refresh can use incremental processing.
-- https://learn.microsoft.com/en-us/fabric/data-engineering/materialized-lake-views/refresh-materialized-lake-view

ALTER TABLE Kantata.HISTORY_SalesOpportunity    SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Opportunity         SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_PerformanceAnalysis SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_TimePeriod          SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_PeriodType          SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_AnalysisFact        SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Account             SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Proposal            SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_DeliveryGroup       SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ForecastStatus      SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ReferenceData       SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_DeliveryElement     SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Resource            SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ResourceType        SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Grade               SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_GradeGroup          SET TBLPROPERTIES (delta.enableChangeDataFeed = true);


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.SalesRevenue
AS

	WITH cteSalesOpps
	AS(
			SELECT	S.Id				AS OpportunityBk 
			FROM	Kantata.HISTORY_SalesOpportunity	S 
			WHERE	S._crda_isDeleted		 = 0 
			AND		S._crda_ActiveToDateTime= '9999-12-31 23:59:59'

			UNION ALL 

			SELECT	O.Id				AS OpportunityBk 
			FROM	Kantata.HISTORY_Opportunity	O 
			WHERE	O._crda_isDeleted		 = 0 
			AND		O._crda_ActiveToDateTime= '9999-12-31 23:59:59'
	), cteSalesRev
	AS(
		SELECT	
			 PA.Id												AS PerformanceAnalysisBk 
			,ROW_NUMBER()	/*PK/Unique constraints are not enforced so...*/ 
				OVER
				(
					PARTITION BY	PA.Id, CAST(TP.KimbleOne__StartDate__c AS DATE) 
					ORDER BY		PA.Id 
				)												AS RN 
		 
			,CAST(TP.KimbleOne__StartDate__c AS DATE)			AS PeriodStartDate
			,CAST(TP.KimbleOne__EndDate__c AS DATE)				AS PeriodEndDate	
			,CAST(TP.FinancialReportingPeriodEnd__c  AS DATE)	AS FinancialReportingPeriodEnd

			,PA.KimbleOne__AnalysisFact__c						AS AnalysisFactBk 

			,PA.KimbleOne__Account__c							AS AccountBk
			,PA.KimbleOne__Proposal__c							AS ProposalBk
			,SO.OpportunityBk									AS SalesOpportunityBk
			,DE.KC_Practice__c									AS DeliveryPracticeBk

			,PA.KimbleOne__Resource__c							AS ResourceBk	
			,R.KC_Practice__c									AS ResourcePracticeBk 
			,PA.KimbleOne__ResourceType__c						AS ResourceTypeBk 

			,FS.Id 												AS ForecastStatusBk
			,PP.KimbleOne__Proposition__c						AS PropositionBk	
			,PA.KimbleOne__DeliveryGroup__c						AS DeliveryGroupBk		
			,PA.KimbleOne__DeliveryElement__c					AS DeliveryElementBk		
			,G.Id												AS GradeBk				
			,GG.Id												AS GradeGroupBk			
			,PA.KimbleOne__AnalysisDimension__c					AS AnalysisDimensionBk	
			,PA.KimbleOne__DomainClass__c						AS DomainClassBk			

			,AC.KimbleOne__BusinessUnit__c						AS AccountBusinessUnitBk
			,R.KimbleOne__BusinessUnit__c						AS ResourceBusinessUnitBk
			,PA.KimbleOne__BusinessUnit__c						AS PaBusinessUnitBk	

			,PA.CurrencyIsoCode 
			,COALESCE(PA.KimbleOne__CorporateCurrencyActualRevenueCalc , 0 )	AS ActualRevenue			
			,COALESCE(PA.WeightedP1OnlyExcActual__c , 0 )						AS WeightedP1OnlyExcActual 
			,COALESCE(((PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc - PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc)
												* 0.01 * FSE.KimbleOne__Probability__c)
										, 0)									AS WeightedP2Only	
			,COALESCE(((PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc - PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc) 
												* 0.01 * FSE.KimbleOne__Probability__c)
										, 0)									AS WeightedP3Only 

			,COALESCE(PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc , 0 )	 AS P1ForecastRevenue 
			,COALESCE(PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc , 0 )	 AS P2ForecastRevenue 
			,COALESCE(PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc , 0 )	 AS P3ForecastRevenue 
			,COALESCE(	CASE WHEN 
							PA.KimbleOne__AnalysisDimension__c = 'a0DD000000B4H55MAF'	/*Account*/
								THEN PA.KimbleOne__CorporateCurrencyTarget__c
								ELSE 0
						END ,  0 )												AS TargetRevenueForAccount 

			,COALESCE(PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc, 0)	AS CorporateCurrencyP1ForecastRevenueCalc 
			,COALESCE(PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc, 0)	AS CorporateCurrencyP2ForecastRevenueCalc 
			,COALESCE(PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc, 0)	AS CorporateCurrencyP3ForecastRevenueCalc 	
			,COALESCE(PA.KimbleOne__CorporateCurrencyActualRevenueCalc, 0)		AS CorporateCurrencyActualRevenueCalc 

			,COALESCE(PA.KimbleOne__CorporateCurrencyActualMarginAmount__c, 0)		AS CorporateCurrencyActualMarginAmount	
			,COALESCE(PA.KimbleOne__CorporateCurrencyP1ForecastMarginAmount__c, 0)	AS CorporateCurrencyP1ForecastMarginAmount	
			,COALESCE(PA.KimbleOne__CorporateCurrencyP2ForecastMarginAmount__c, 0)	AS CorporateCurrencyP2ForecastMarginAmount	
			,COALESCE(PA.KimbleOne__CorporateCurrencyP3ForecastMarginAmount__c, 0)	AS CorporateCurrencyP3ForecastMarginAmount 

			,COALESCE(PA.KimbleOne__CorporateCurrencyActualCost__c , 0 )			AS ActualCost	
			,COALESCE(PA.KimbleOne__CorporateCurrencyP1ForecastCost__c, 0)			AS CorporateCurrencyP1ForecastCost 
			,COALESCE(PA.KimbleOne__CorporateCurrencyP2ForecastCost__c, 0)			AS CorporateCurrencyP2ForecastCost 
			,COALESCE(PA.KimbleOne__CorporateCurrencyP3ForecastCost__c, 0)			AS CorporateCurrencyP3ForecastCost 


			,CASE WHEN (PA.KimbleOne__DomainClass__c <> 'a0dD00000076nKRIAY' /*Expenses*/ 
							OR PA.KimbleOne__DomainClass__c IS NULL)
					THEN 1 ELSE 0 END								AS ExpensesFlag 
			,RA.KC_DMW_Activity_Type__c								AS DmwActivityType 									
			,CASE WHEN FSE.Id IS NULL 
					THEN FS.KimbleOne__Probability__c 
						ELSE FSE.KimbleOne__Probability__c END		AS ProbabilityFactor 
			,PA.Element_Product__c									AS ElementProduct 
			,CASE WHEN PA.KC_NewBusiness__c = 0 THEN 0 ELSE 1 END	AS IsNewBusiness 
			,PA.RevenueGenerationModel__c							AS RevenueGenerationModel 
			,PA.KC_IsBalancingRecord__c								AS IsBalancingRecord 
			,FS.KimbleOne__ProbabilityCode__c						AS ProbabilityCodeBk 
			,RD.Name												AS ProbabilityCode 
			,PA._crda_ActiveFromDateTime 
			,PA._crda_ActiveToDateTime


		FROM		Kantata.HISTORY_PerformanceAnalysis	PA 

		INNER JOIN	Kantata.HISTORY_TimePeriod			TP	ON	TP.Id				= PA.KimbleOne__TimePeriod__c
															AND TP._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	TP._crda_isDeleted	= 0

		INNER JOIN	Kantata.HISTORY_PeriodType			PT	ON	PT.Id				= TP.KimbleOne__PeriodType__c 
															AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
															AND PT._crda_isDeleted	= 0
															AND	PT.Name				= 'Month'

		INNER JOIN	Kantata.HISTORY_AnalysisFact		AF	ON	AF.Id				= PA.KimbleOne__AnalysisFact__c
															AND AF._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	AF._crda_isDeleted	= 0
																			/*'Revenue'			'Cost'					RevenueInternal			CostInternal*/
															AND AF.Id IN ('a0ED000000CxJIuMAN', 'a0ED000000CxJIvMAN', 'a0E3z00000uZEf6EAG', 'a0E3z00000uZEf7EAG')

		LEFT JOIN	Kantata.HISTORY_Account				AC	ON	AC.Id				= PA.KimbleOne__Account__c 
															AND AC._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	AC._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_Proposal			PP	ON	PP.Id				= PA.KimbleOne__Proposal__c
															AND PP._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	PP._crda_isDeleted	= 0

		LEFT JOIN	cteSalesOpps						SO	ON SO.OpportunityBk = PP.OpportunityId

		LEFT JOIN	Kantata.HISTORY_DeliveryGroup		DG	ON	DG.Id				= PA.KimbleOne__DeliveryGroup__c
															AND DG._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	DG._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_ForecastStatus		FS	ON	FS.Id				= DG.KimbleOne__ForecastStatus__c
															AND FS._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
															AND	FS._crda_isDeleted	= 0 

		LEFT JOIN	Kantata.HISTORY_ReferenceData		RD	ON	RD.Id				= FS.KimbleOne__ProbabilityCode__c 
															AND	RD._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
															AND	RD._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_DeliveryElement		DE 	ON	DE.Id				= PA.KimbleOne__DeliveryElement__c
															AND DE._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	DE._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_ForecastStatus		FSE ON	FSE.Id				= DE.KimbleOne__ForecastStatus__c
															AND FSE._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	FSE._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_Resource			R	ON	R.Id				= PA.KimbleOne__Resource__c
															AND R._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
															AND	R._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_ResourceType		RT	ON	RT.Id				= R.KimbleOne__ResourceType__c 
															AND RT._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
															AND	RT._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_Grade				G	ON	G.Id				= R.KimbleOne__Grade__c
															AND G._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
															AND	G._crda_isDeleted	= 0

		LEFT JOIN	Kantata.HISTORY_GradeGroup			GG	ON	GG.Id				= G.DMW_GradeGroup__c 
															AND GG._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
															AND	GG._crda_isDeleted	= 0 

		LEFT JOIN	Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id	= PA.KimbleOne__ResourcedActivity__c 
															AND	RA._crda_ActiveToDateTime = '9999-12-31 23:59:59'
															AND	RA._crda_isDeleted = 0 

		WHERE	PA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
		AND		(PA.KimbleOne__DomainClass__c <> 'a0dD00000076nKRIAY' /*Expenses*/
						OR PA.KimbleOne__DomainClass__c IS NULL) 
		AND		PA._crda_isDeleted	= 0 
	)
	SELECT 
		SRC.PerformanceAnalysisBk , 
		SRC.PeriodStartDate , 
		SRC.PeriodEndDate , 
		SRC.FinancialReportingPeriodEnd , 
		SRC.AnalysisFactBk , 

		SRC.AccountBk , 

		SRC.ProposalBk	, 
		SRC.SalesOpportunityBk ,
		SRC.DeliveryPracticeBk ,

		SRC.ResourceBk , 
		SRC.ResourcePracticeBk , 
		SRC.ResourceTypeBk , 

		SRC.ForecastStatusBk , 
		SRC.PropositionBk , 
		SRC.DeliveryGroupBk , 
		SRC.DeliveryElementBk ,
		SRC.GradeBk ,
		SRC.GradeGroupBk , 
		SRC.AnalysisDimensionBk , 
		SRC.DomainClassBk , 

		SRC.AccountBusinessUnitBk , 
		SRC.ResourceBusinessUnitBk , 
		SRC.PaBusinessUnitBk , 

		SRC.CurrencyIsoCode ,
		SRC.ActualRevenue , 
		SRC.WeightedP1OnlyExcActual , 
		SRC.WeightedP2Only ,
		SRC.WeightedP3Only , 
		SRC.P1ForecastRevenue , 
		SRC.P2ForecastRevenue , 
		SRC.P3ForecastRevenue , 
		SRC.TargetRevenueForAccount , 

		SRC.CorporateCurrencyP1ForecastRevenueCalc ,
		SRC.CorporateCurrencyP2ForecastRevenueCalc , 
		SRC.CorporateCurrencyP3ForecastRevenueCalc , 
		SRC.CorporateCurrencyActualRevenueCalc ,

		SRC.CorporateCurrencyActualMarginAmount , 
		SRC.CorporateCurrencyP1ForecastMarginAmount , 
		SRC.CorporateCurrencyP2ForecastMarginAmount , 
		SRC.CorporateCurrencyP3ForecastMarginAmount , 

		SRC.ActualCost , 
		SRC.CorporateCurrencyP1ForecastCost , 
		SRC.CorporateCurrencyP2ForecastCost , 
		SRC.CorporateCurrencyP3ForecastCost , 

		SRC.ExpensesFlag ,
		SRC.DmwActivityType ,
		SRC.ProbabilityFactor , 
		SRC.ElementProduct ,
		SRC.IsNewBusiness , 
		SRC.RevenueGenerationModel , 
		SRC.IsBalancingRecord , 

		SRC.ProbabilityCodeBk , 
		SRC.ProbabilityCode , 

		SRC._crda_ActiveFromDateTime , 
		SRC._crda_ActiveToDateTime

	FROM	cteSalesRev SRC 
	WHERE	SRC.RN = 1 ; 


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT * FROM Internal.SalesRevenue   ;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
