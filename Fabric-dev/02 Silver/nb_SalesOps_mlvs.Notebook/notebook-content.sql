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

DROP MATERIALIZED LAKE VIEW IF EXISTS Internal.SalesOpportunityUnion ;


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

--CREATE MATERIALIZED LAKE VIEW IF NOT EXISTS Internal.SalesOpportunityUnion
CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.SalesOpportunityUnion
AS

    SELECT	  
          S.Id								AS OpportunityBk
        , S.CreatedDate
        , S.KimbleOne__Account__c			AS AccountBk				
        , S.Related_Opportunity__c			AS RelatedOpportunityBk	
        , S.KimbleOne__OpportunityStage__c	AS OpportunityStageBk 		
        , S.KimbleOne__OpportunitySource__c	AS OpportunitySourceBk		
        , S.KimbleOne__MarketingCampaign__c	AS MarketingCampaignBk		
        , S.SectorId__c						AS SectorBk 
        , S.Sector__c						AS Sector
        , S.Proposed_Delivery_Program__c	AS ProposedDeliveryProgramBk
        , S.CommercialSignoff__c			AS CommercialSignoffBk 	
        , S.Originator__c					AS OriginatorBk			
        , S.OwnerId							AS OwnerId					

        , S.LinkToProposal__c				AS LinkToProposal		
        , S.TypeofWork__c					AS TypeofWork			
        , S.KimbleOne__CloseDate__c			AS CloseDate			
        , S.KimbleOne__CloseDate__c			AS ResponseRequiredDate
        , S.KimbleOne__WonLostReason__c		AS WonLostReason		
        , NULL								AS ClosePlanAccurate	
        , NULL								AS StandardRateCardUsed
        , NULL								AS OrganicGrowth		
        , S.KimbleOne__Proposal__c			AS ProposalBk			
        , S.KimbleOne__ForecastStatus__c	AS ForecastStatusBk	
        , S.BidStatus__c					AS BidStatus			
        , S.BidFramework__c					AS BidFramework		
        , S.BidPQQDueDate__c				AS BidPQQDueDate		
        , S.BidPQQStatus__c					AS BidPQQStatus		
        , S._crda_ActiveFromDateTime
        , S._crda_ActiveToDateTime 

    FROM	Kantata.HISTORY_SalesOpportunity	S 

    LEFT JOIN Kantata.HISTORY_ForecastStatus	F	ON	F.Id	= S.KimbleOne__ForecastStatus__c 
                                                    AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
                                                    AND	F._crda_isDeleted		 = 0 

    WHERE	S._crda_isDeleted		 = 0 
--	AND		S._crda_ActiveToDateTime= '9999-12-31 23:59:59' 

    UNION ALL 

    SELECT	
          O.Id 
        , O.CreatedDate
        , O.AccountId							AS AccountBk				
        , CAST(NULL AS VARCHAR(18))				AS RelatedOpportunityBk 	
        , CAST(NULL AS VARCHAR(18))				AS OpportunityStageBk 		
        , CAST(NULL AS VARCHAR(18))				AS OpportunitySourceBk		
        , O.CampaignId							AS MarketingCampaignBk		
        , SC.Id									AS SectorBk	
        , SC.Name								AS Sector 
        , O.KC_Proposed_Delivery_Program__c		AS ProposedDeliveryProgramBk
        , CAST(NULL AS VARCHAR(18))				AS CommercialSignoffBk		
        , O.KC_Originator__c					AS OriginatorBk			
        , O.OwnerId

        , O.KC_Link_To_Proposal__c				AS LinkToProposal			
        , O.Type								AS TypeofWork				
        , O.CloseDate 
        , O.CloseDate							AS ResponseRequiredDate	
        , O.Reason_Lost__c						AS WonLostReason			
        , O.Close_Plan_Accurate__c				AS ClosePlanAccurate		
        , O.Standard_Rate_Card_Used__c			AS StandardRateCardUsed	
        , O.Organic_Growth__c					AS OrganicGrowth			
        , O.KimbleOne__Proposal__c				AS ProposalBk				
        , F.Id									AS ForecastStatusBk		
        , NULL									AS BidStatus				
        , NULL									AS BidFramework			
        , NULL									AS BidPQQDueDate			
        , NULL									AS BidPQQStatus			
        , O._crda_ActiveFromDateTime 
        , O._crda_ActiveToDateTime 

    FROM		Kantata.HISTORY_Opportunity	O 
    LEFT JOIN	Kantata.HISTORY_Account		A	ON	A.Id	= O.AccountId 
                                                AND	A._crda_ActiveToDateTime= '9999-12-31 23:59:59'
                                                AND	A._crda_isDeleted		 = 1 

    LEFT JOIN ( /*ForecastStatus.Name values changed Dec 2025*/
        SELECT	Id, Name, 
                _crda_ActiveToDateTime , 
                ROW_NUMBER()OVER(
                        PARTITION BY Name 
                        ORDER BY _crda_ActiveToDateTime)    AS RN 
        FROM	Kantata.HISTORY_ForecastStatus F 
        WHERE	F._crda_isDeleted = 1 
    )										FH	ON	FH.Name = O.StageName 
                                                AND	FH.RN = 1

    LEFT JOIN Kantata.HISTORY_Account		AC	ON	AC.Id					= O.AccountId  
                                                AND	AC._crda_ActiveToDateTime= '9999-12-31 23:59:59'
                                                    AND	AC._crda_isDeleted		 = 0 

    LEFT JOIN Kantata.HISTORY_ForecastStatus	F	ON	F.Id					= FH.Id 
                                                    AND	F._crda_ActiveToDateTime= '9999-12-31 23:59:59'
                                                    AND	F._crda_isDeleted		= 0 

    LEFT JOIN Kantata.HISTORY_Sector	SC	ON	SC.Name				= A.SectorName__c 
                                            AND	SC._crda_ActiveToDateTime= '9999-12-31 23:59:59'
                                            AND	SC._crda_isDeleted		 = 0  

    WHERE	O._crda_isDeleted		 = 0  
--	AND		O._crda_ActiveToDateTime= '9999-12-31 23:59:59' 


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT * FROM Internal.SalesOpportunityUnion ; 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

DROP MATERIALIZED LAKE VIEW IF EXISTS Internal.SalesOpportunity ; 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************


CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.SalesOpportunity 
AS

WITH cteSalesOpsData
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
			CASE FSS.Name
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
			CASE FSS.Name
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

	INNER JOIN	Internal.salesopportunityunion		SO	ON	SO.OpportunityBk			= PR.OpportunityId 
														AND	SO._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

	LEFT JOIN	Kantata.HISTORY_Sector			SC	ON	SC.Name					= SO.Sector
													AND	SC._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
													AND	SC._crda_isDeleted			= 0 

	LEFT JOIN	Kantata.HISTORY_ForecastStatus	FS	ON	FS.Name					= PA.DeliveryElementStatus__c 
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

-- CELL ********************


CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.SalesOpportunityLifecycle
AS

	WITH cteSalesOpportunityLifecycle 
	AS (
		SELECT	 
			 SO.OpportunityBk						AS SalesOpportunityBk		
			,SO._crda_ActiveFromDateTime			AS SalesOpportunitytDateTime
			,AC.KimbleOne__BusinessUnit__c			AS AccountBusinessUnitBk	
			,AC.Id									AS AccountBk				
			,PS.KimbleOne__BusinessUnit__c			AS ProposalBusinessUnitBk	
			,SO.ProposalBk							AS ProposalBk				
			,SO.RelatedOpportunityBk				AS RelatedSalesOpportunityBk
			,SO.ForecastStatusBk					AS ForecastStatusBk		
			,SO.OpportunityStageBk					AS OpportunityStageBk		
			,SO.OpportunitySourceBk					AS OpportunitySourceBk	
			,SO.SectorBk							AS SectorBk				
			,PS.KimbleOne__Proposition__c			AS PropositionBk			
			,SO.MarketingCampaignBk					AS MarketingCampaignBk	
			,SO.ProposedDeliveryProgramBk			AS ProposedDeliveryProgramBk
			,SO.OriginatorBk						AS OriginatorBk			
			,SO.CommercialSignoffBk					AS CommercialSignOffBk	
			,SO.OwnerId								AS SalesOpportunityOwnerBk
			,PS.OwnerId								AS ProposalOwnerBk		
			,SO.CloseDate							AS CloseDate				
			,PS.KimbleOne__AcceptanceDate__c		AS AcceptanceDate			
			,SO.ResponseRequiredDate				AS ResponseRequiredDate	
			,PS.earliestStartDate__c				AS EarliestStartDate		
			,PS.latestEndDate__c					AS LatestEndDate			
			,PS.KimbleOne__DeliveryStartDate__c		AS DeliveryStartDate		
			,COALESCE(PS.CurrencyIsoCode , 'ZZZ')		AS CurrencyIsoCode		
			,COALESCE(SO.WonLostReason , '')			AS WonLostReason			
			,SO.BidStatus							AS BidStatus				
			,SO.BidFramework						AS BidFramework	
			,CAST(SO.BidPQQDueDate AS DATE)			AS BidPQQDueDate	
			,SO.BidPQQStatus						AS BidPQQStatus	
			,COALESCE(PS.KimbleOne__ContractRevenue__c , 0)				AS ContractRevenue	
			,COALESCE(PS.KimbleOne__ContractMargin__c , 0)				AS ContractMargin	
			,COALESCE(PS.KimbleOne__ContractCost__c , 0)				AS ContractCost	
			,COALESCE(PS.KimbleOne__ContractMarginAmount__c , 0)		AS ContractMarginAmount	
			,COALESCE(PS.KimbleOne__ContractMargin__c , 0)				AS ContractMarginPercentage
			,COALESCE(PS.KimbleOne__WeightedContractRevenue__c , 0)		AS WeightedContractRevenue
			,IF(COALESCE(CAST(PS.KimbleOne__ForecastAtDetailedLevel__c AS INT), 0 ) = 0, 0 , 1)	AS IsForecastedAtDetailedLevel 
			,COALESCE(PS.KimbleOne__DetailedLevelContractCost__c , 0)					AS DetailedLevelContractCost	
			,COALESCE(PS.KimbleOne__DetailedLevelContractRevenue__c , 0)				AS DetailedLevelContractRevenue	
			,COALESCE(PS.KimbleOne__DetailedLevelWeightedContractRevenue__c , 0)		AS DetailedLevelWeightedContractRevenue	
			,COALESCE(PS.KimbleOne__HighLevelContractCost__c , 0)						AS HighLevelContractCost	
			,COALESCE(PS.KimbleOne__HighLevelContractRevenue__c , 0)					AS HighLevelContractRevenue	
			,COALESCE(PS.KimbleOne__HighLevelWeightedContractRevenue__c , 0)			AS HighLevelWeightedContractRevenue
			,COALESCE(PS.KimbleOne__ProposalCost__c , 0)				AS ProposalCost		
			,COALESCE(PS.KimbleOne__ProposalExpensesCost__c , 0)		AS ProposalExpenseCost	
			,COALESCE(PS.KimbleOne__ProposalMarginAmount__c , 0)		AS ProposalMarginAmount	
			,COALESCE(PS.KimbleOne__ProposalMargin__c , 0)				AS ProposalMarginPercentage
			,COALESCE(PS.KimbleOne__ProposalUsageCost__c , 0)			AS ProposalUsageCost	
			,COALESCE(PS.KimbleOne__Discount__c , 0)					AS DiscountAmount		
			,COALESCE(PS.KimbleOne__DiscountPercentage__c , 0)			AS DiscountPercentage	
			,IF(COALESCE(CAST(PS.DMW_Element_is_WAR__c AS INT), 0 ) = 0, 0, 1)	AS DMWElementIsWAR	
			,ROW_NUMBER() 
					OVER (
						PARTITION BY	SO.OpportunityBk, SO._crda_ActiveFromDateTime 
						ORDER BY		SO.OpportunityBk, SO._crda_ActiveFromDateTime 
						)						AS RN 


		FROM	Internal.salesopportunityunion			 SO	

		LEFT JOIN	Kantata.HISTORY_Account	AC	ON	AC.Id = SO.AccountBk 
												AND	AC._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
												AND	AC._crda_isDeleted = 0 

		LEFT  JOIN	Kantata.HISTORY_Proposal	PS	ON	PS.OpportunityId = SO.OpportunityBk  
													AND	PS._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
													AND	PS._crda_isDeleted = 0 
	) 
	SELECT 
		 SRC.SalesOpportunityBk
		,SRC.SalesOpportunitytDateTime 
		,SRC.AccountBusinessUnitBk
		,SRC.AccountBk
		,SRC.ProposalBusinessUnitBk 
		,SRC.ProposalBk
		,SRC.RelatedSalesOpportunityBk
		,SRC.ForecastStatusBk
		,SRC.OpportunityStageBk
		,SRC.OpportunitySourceBk
		,SRC.SectorBk
		,SRC.PropositionBk
		,SRC.MarketingCampaignBk
		,SRC.ProposedDeliveryProgramBk
		,SRC.OriginatorBk
		,SRC.CommercialSignOffBk
		,SRC.SalesOpportunityOwnerBk
		,SRC.ProposalOwnerBk
		,SRC.CloseDate
		,SRC.AcceptanceDate
		,SRC.ResponseRequiredDate
		,SRC.EarliestStartDate
		,SRC.LatestEndDate
		,SRC.DeliveryStartDate
		,SRC.CurrencyIsoCode
		,SRC.WonLostReason
		,SRC.BidStatus
		,SRC.BidFramework
		,SRC.BidPQQDueDate
		,SRC.BidPQQStatus
		,SRC.ContractRevenue
		,SRC.ContractMargin
		,SRC.ContractCost
		,SRC.ContractMarginAmount
		,SRC.ContractMarginPercentage
		,SRC.WeightedContractRevenue
		,SRC.IsForecastedAtDetailedLevel
		,SRC.DetailedLevelContractCost
		,SRC.DetailedLevelContractRevenue
		,SRC.DetailedLevelWeightedContractRevenue
		,SRC.HighLevelContractCost
		,SRC.HighLevelContractRevenue
		,SRC.HighLevelWeightedContractRevenue
		,SRC.ProposalCost
		,SRC.ProposalExpenseCost
		,SRC.ProposalMarginAmount
		,SRC.ProposalMarginPercentage
		,SRC.ProposalUsageCost
		,SRC.DiscountAmount
		,SRC.DiscountPercentage
		,SRC.DMWElementIsWAR

	FROM cteSalesOpportunityLifecycle SRC 
	WHERE	RN = 1 
	ORDER BY SalesOpportunityBk, SalesOpportunitytDateTime ;


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }
