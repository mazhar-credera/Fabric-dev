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
ALTER TABLE Kantata.HISTORY_Proposal            SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Proposition         SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ForecastStatus      SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Opportunity         SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Account             SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_PerformanceAnalysis SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_AnalysisFact        SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Sector              SET TBLPROPERTIES (delta.enableChangeDataFeed = true);

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- 
CREATE MATERIALIZED LAKE VIEW IF NOT EXISTS Internal.SalesOpportunity 
AS

	WITH cteSalesOpps
	AS(
			SELECT	 S.Id								AS OpportunityBk 
					,S.CreatedDate 
					,S.KimbleOne__ForecastStatus__c		AS ForecastStatusBk	
					,S.KimbleOne__OpportunitySource__c	AS OpportunitySourceBk
					,S.Sector__c							AS Sector		
			FROM		Kantata.HISTORY_SalesOpportunity	S 

			LEFT JOIN	Kantata.HISTORY_Proposal	P	ON	P.Id					= S.KimbleOne__Proposal__c 
														AND	P._crda_ActiveToDateTime= '9999-12-31 23:59:59'
														AND	P._crda_isDeleted		 = 0 

			LEFT JOIN	Kantata.HISTORY_Proposition	PP	ON	PP.Id					= P.KimbleOne__Proposition__c 
														AND	PP._crda_ActiveToDateTime= '9999-12-31 23:59:59'
														AND	PP._crda_isDeleted		 = 0 

			LEFT JOIN Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= S.KimbleOne__ForecastStatus__c 
														AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
														AND	F._crda_isDeleted		= 0 

			WHERE	S._crda_isDeleted		 = 0 
			AND		S._crda_ActiveToDateTime= '9999-12-31 23:59:59'

			UNION ALL 

			SELECT	 O.Id						AS OpportunityBk
					,O.CreatedDate 
					,F.Id						AS ForecastStatusBk	
					,CAST(NULL AS VARCHAR(18)) 	AS OpportunitySourceBk	
					,O.KC_Sector__c				AS Sector	
			FROM		Kantata.HISTORY_Opportunity	O 

			LEFT JOIN	Kantata.HISTORY_Account		A	ON	A.Id	= O.AccountId 
														AND	A._crda_ActiveToDateTime= '9999-12-31 23:59:59'
														AND	A._crda_isDeleted		 = 0 

			LEFT JOIN ( /*ForecastStatus.Name values changed Dec 2025*/
				SELECT	Id, `Name`, _crda_ActiveToDateTime , 
						ROW_NUMBER()OVER(
								PARTITION BY `Name` 
								ORDER BY _crda_ActiveToDateTime) AS RN 
				FROM	Kantata.HISTORY_ForecastStatus F 
				WHERE	F._crda_isDeleted = 0 
			)										FH	ON	FH.`Name` = O.StageName 
														AND	FH.RN = 1

			LEFT JOIN Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= FH.Id 
															AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
															AND	F._crda_isDeleted		 = 0 

			LEFT JOIN Kantata.HISTORY_Proposal	P	ON	P.Id					= O.KimbleOne__Proposal__c 
													AND	P._crda_ActiveToDateTime= '9999-12-31 23:59:59'
													AND	P._crda_isDeleted		 = 0 

			LEFT JOIN Kantata.HISTORY_Proposition	PP	ON	PP.Id					= P.KimbleOne__Proposition__c 
													AND	PP._crda_ActiveToDateTime= '9999-12-31 23:59:59'
													AND	PP._crda_isDeleted		 = 0 

			WHERE	O._crda_isDeleted		 = 0 
			AND		O._crda_ActiveToDateTime= '9999-12-31 23:59:59'
	), cteSalesOpsData
	AS ( 
	SELECT  
		 SO.OpportunityBk			AS SalesOpportunityBk	
		,SO.CreatedDate				AS SalesOpsCreatedDateTime
		,PA.Id						AS PerformanceAnalysisBk
		,PA.KimbleOne__Account__c	AS AccountBk	
		,PA.KimbleOne__Proposal__c  AS ProposalBk	
		,SO.ForecastStatusBk		AS SalesOpForecastStatusBk 
		,FS.Id						AS PaForecastStatusBk	
		,SO.OpportunitySourceBk		AS OpportunitySourceBk	
		,SC.Id						AS SectorBk		
		,AF.Id						AS AnalysisFactBk	
		,PA.KimbleOne__BusinessUnit__c   AS PaBusinessUnitBk 

		,COALESCE(PA.KimbleOne__ActualRevenue__c
						+ PA.WeightedP1OnlyExcActual__c 
								+ PA.WeightedP2Only__c 
									+ PA.WeightedP3Only__c , 0) AS TotalRevenue	 

		,COALESCE(	
			CASE FSS.`Name`
				WHEN '1. Lead (1%)'			THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3
				WHEN '2. Qualify (10%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3		
				WHEN '3. Solutions (25%)'	THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3
				WHEN '4. Propose (50%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P3
				WHEN '5. Negotiate (75%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc * (FSS.KimbleOne__Probability__c * 0.01)		--P2
				WHEN '6. Verbal Win (90%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	* (FSS.KimbleOne__Probability__c * 0.01)	--P2
				WHEN '7. Firm (100%)'		THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1
				WHEN 'Working at Risk (100%)'THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1												
				ELSE 0
			END , 0)											AS WeightedRevenue
		,COALESCE(	
			CASE FSS.`Name`
				WHEN '1. Lead (1%)'			THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
				WHEN '2. Qualify (10%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
				WHEN '3. Solutions (25%)'	THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
				WHEN '4. Propose (50%)'		THEN PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	--P3
				WHEN '5. Negotiate (75%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	--P2
				WHEN '6. Verbal Win (90%)'	THEN PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	--P2
				WHEN '7. Firm (100%)'		THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1
				WHEN 'Working at Risk (100%)'THEN PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	--P1
				ELSE 0 
			END , 0)											AS UnweightedRevenue
		,PA._crda_ActiveFromDateTime 
		,ROW_NUMBER()	/*PK/Unique constraints are not enforced so...*/ 
				OVER (
					PARTITION BY	SO.OpportunityBk, SO.CreatedDate, PA.Id	 
					ORDER BY		SO.OpportunityBk, SO.CreatedDate	 
				)												AS RN 

	FROM		Kantata.HISTORY_PerformanceAnalysis    PA     

	INNER JOIN	Kantata.HISTORY_AnalysisFact		AF	ON  AF.Id						= PA.KimbleOne__AnalysisFact__c 
														AND	AF._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
														AND	AF._crda_isDeleted			= 0 
																		/*'Revenue'			'Cost'					RevenueInternal			CostInternal*/
														AND AF.Id IN ('a0ED000000CxJIuMAN', 'a0ED000000CxJIvMAN', 'a0E3z00000uZEf6EAG', 'a0E3z00000uZEf7EAG')	

	INNER JOIN	Kantata.HISTORY_Proposal			PR	ON	PR.Id						= PA.KimbleOne__Proposal__c 
														AND	PR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
														AND	PR._crda_isDeleted			= 0 

	INNER JOIN	cteSalesOpps						SO	ON	SO.OpportunityBk			= PR.OpportunityId 

	LEFT JOIN	Kantata.HISTORY_Sector			SC	ON	SC.`Name`					= SO.Sector
													AND	SC._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
													AND	SC._crda_isDeleted			= 0 

	LEFT JOIN	Kantata.HISTORY_ForecastStatus	FS	ON	FS.`Name`					= PA.DeliveryElementStatus__c 
													AND	FS._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
													AND	FS._crda_isDeleted			= 0 

	LEFT JOIN	Kantata.HISTORY_ForecastStatus	FSS	ON	FSS.Id						= SO.ForecastStatusBk  
													AND	FSS._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
													AND	FSS._crda_isDeleted			= 0 

	WHERE	PA._crda_isDeleted = 0 
	AND		PA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
) 
	SELECT 
		SRC.SalesOpportunityBk , 
		SRC.SalesOpsCreatedDateTime , 
		SRC.PerformanceAnalysisBk , 
		SRC.AccountBk , 
		SRC.ProposalBk ,
		SRC.SalesOpForecastStatusBk , 
		SRC.PaForecastStatusBk	, 
		SRC.OpportunitySourceBk ,
		SRC.SectorBk ,
		SRC.AnalysisFactBk , 
		SRC.PaBusinessUnitBk , 

		SRC.TotalRevenue ,
		SRC.WeightedRevenue ,
		SRC.UnweightedRevenue 

	FROM	cteSalesOpsData	SRC 
	WHERE	SRC.RN = 1 



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT * FROM Internal.SalesOpportunity 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
