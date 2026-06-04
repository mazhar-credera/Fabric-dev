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
-- A replacement for Internal.usp_Update_DemandActivity that would've lived in the Gold warehouse
-- CREATE MATERIALIZED LAKE VIEW <mlv_name> AS select_statement
CREATE SCHEMA IF NOT EXISTS Internal;


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

-- Enable change data feed (CDF) on the source tables so that optimal refresh can use incremental processing.
-- https://learn.microsoft.com/en-us/fabric/data-engineering/materialized-lake-views/refresh-materialized-lake-view

ALTER TABLE Kantata.HISTORY_ActivityAssignment          SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ActivityAssignmentDemand    SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Resource                    SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ActivityRole                SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ResourcedActivity           SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_DeliveryElement             SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_DeliveryGroup               SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ForecastStatus              SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ReferenceData               SET TBLPROPERTIES (delta.enableChangeDataFeed = true);



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.DemandActivity 
AS



	WITH cteDemandActivity
	AS( 
		SELECT	
			 AA.Id										AS	 ActivityAssignmentBk
			,AA.KimbleOne__ActivityAssignmentDemand__c	AS	ActivityAssignmentDemandBk
			,AA.KimbleOne__Resource__c					AS	ResourceBk
		
			,CAST(AA.KimbleOne__StartDate__c AS DATE) 			AS	DemandStart
			,CAST(AA.KimbleOne__ForecastP3EndDate__c AS DATE) 	AS	DemandEnd
			,CAST(LAST_DAY(AA.KimbleOne__StartDate__c) AS DATE)		AS	DemandStartMonthEnd
			,CAST(LAST_DAY(AA.KimbleOne__ForecastP3EndDate__c)AS DATE)AS	DemandEndMonthEnd
		
			,CAST( AA.KimbleOne__EarliestTimeEntryDate__c AS DATE)	AS	EarliestTimeEntryDate
			,CAST( AA.KimbleOne__LatestTimeEntryDate__c AS DATE) 	AS	LatestTimeEntryDate
			,CAST( AA.KimbleOne__ForecastP1EndDate__c AS DATE ) 	AS	ForecastP1EndDate
			,CAST( AA.KimbleOne__ForecastP2EndDate__c AS DATE) 		AS	ForecastP2EndDate
			,CAST( AA.KimbleOne__ForecastP3EndDate__c AS DATE) 		AS	ForecastP3EndDate

			/*Workaround for PK/Unique constraints are not enforced so...*/
			,ROW_NUMBER() 
				OVER (
					PARTITION BY	AA.Id , AA.KimbleOne__Resource__c , CAST(AA.KimbleOne__StartDate__c AS DATE)
					ORDER BY		CAST(AA.KimbleOne__StartDate__c AS DATE) 
				) AS RN 

			,AA.KimbleOne__IncludeInRollUp__c		AS	IncludeInRollUp
			,AA.KimbleOne__ResourcedActivity__c	AS	ResourcedActivityBk
		
			,AA.KimbleOne__ActivityRole__c		AS	ActivityAssgnRoleBk
			,AAD.ActivityRole__c				AS	ActivityAssignmentDemandRole
			,AR.Practice__c					AS	ActivityRolePracticeBk
			,AA.KimbleOne__CandidateStatus__c	AS	CandidateStatusBk
		
			,R.KimbleOne__Location__c			AS	ResourceLocationBk
			,AA.KimbleOne__Location__c			AS	ActivityLocationBk
			,AA.KimbleOne__DeliveryGroup__c	AS	ActivityDeliveryGroupBk
			,DG.KimbleOne__Account__c			AS	DeliveryGroupAccountBk
			,DG.KimbleOne__ForecastStatus__c	AS	DeliveryGroupForecastStatusBk
			,AAD.KimbleOne__Status__c 			AS	ActivityDemandStatusBk
			,AAD.KimbleOne__ResourcingStatus__c	AS	ResourcingStatusBk
		
			,AA.CurrencyIsoCode												AS	CurrencyIsoCode
			,CAST( AA.KimbleOne__ForecastRevenueRate__c AS DECIMAL(18,2) ) 	AS	RevenueRate
		
			,CAST( AA.KimbleOne__TotalActualCost__c AS DECIMAL(18,2) )		AS	TotalActualCost
			,CAST( AA.KimbleOne__ForecastP1Cost__c AS DECIMAL(18,2) ) 		AS	ForecastP1Cost
			,CAST( AA.KimbleOne__ForecastP2Cost__c AS DECIMAL(18,2) ) 		AS	ForecastP2Cost
			,CAST( AA.KimbleOne__ForecastP3Cost__c AS DECIMAL(18,2) ) 		AS	ForecastP3Cost
		
			,CAST( AA.KimbleOne__TotalActualRevenue__c  AS DECIMAL(18,2)) 	AS	TotalActualRevenue
			,CAST( AA.KimbleOne__ForecastP1Revenue__c  AS DECIMAL(18,2)) 	AS	ForecastP1Revenue
			,CAST( AA.KimbleOne__ForecastP2Revenue__c  AS DECIMAL(18,2)) 	AS	ForecastP2Revenue
			,CAST( AA.KimbleOne__ForecastP3Revenue__c  AS DECIMAL(18,2)) 	AS	ForecastP3Revenue
		
			,CAST( AA.KimbleOne__TotalActualUsage__c AS DECIMAL(18,2)) 		AS	TotalActualUsage
			,CAST( AA.KimbleOne__ForecastP1Usage__c  AS DECIMAL(18,2)) 		AS	ForecastP1Usage
			,CAST( AA.KimbleOne__ForecastP2Usage__c  AS DECIMAL(18,2)) 		AS	ForecastP2Usage
			,CAST( AA.KimbleOne__ForecastP3Usage__c  AS DECIMAL(18,2)) 		AS	ForecastP3Usage
		
			,CAST( AA.KimbleOne__BaselineCost__c  AS DECIMAL(18,2)) 		AS	BaselineCost
			,CAST( AA.KimbleOne__BaselineMargin__c  AS DECIMAL(18,2)) 		AS	BaselineMargin
			,CAST( AA.KimbleOne__BaselineMarginAmount__c AS DECIMAL(18,2))	AS	BaselineMarginAmount
			,CAST( AA.KimbleOne__BaselineRevenue__c  AS DECIMAL(18,2)) 		AS	BaselineRevenue
			,CAST( AA.KimbleOne__BaselineUsage__c  AS DECIMAL(18,2)) 		AS	BaselineUsage
			,CAST( AA.KimbleOne__BaselineUtilisationPercentage__c  AS DECIMAL(18,2) )	AS	BaselineUtilisationPercentage
		
			,CAST( AA.KimbleOne__AssignmentPercentage__c  AS DECIMAL(18,2)) 		AS	AssignmentPercentage
			,CAST( AA.KimbleOne__DefaultCostRatePercentage__c  AS DECIMAL(18,2)) 	AS	DefaultCostRatePercentage
			,CAST( AA.KimbleOne__DefaultRevenueRatePercentage__c AS DECIMAL(18,2))	AS	DefaultRevenueRatePercentage
			,CAST( AA.KimbleOne__DiscountPercentage__c  AS DECIMAL(18,2)) 			AS	DiscountPercentage
			,CAST( AA.KimbleOne__UtilisationPercentage__c  AS DECIMAL(18,2)) 		AS	UtilisationPercentage
		
			,RA.KimbleOne__BusinessUnit__c				AS	ResourcedActivityBusinessUnitBk
			,RA.KimbleOne__ResourcedActivityType__c		AS	ResourcedActivityTypeBk
			,RA.Activity_Group__c						AS	ActivityGroup
			,RA.KimbleOne__DeliveryElement__c			AS	ResourceDeliveryElementBk
		
			,AAD.Demand_Ref__c							AS	DemandRef
			,AA.KimbleOne__LongNotes__c					AS	ActivityAssignmentLogNotes

		FROM		Kantata.HISTORY_ActivityAssignment		AA  

		LEFT JOIN	Kantata.HISTORY_ActivityAssignmentDemand AAD	ON	AAD.Id				= AA.KimbleOne__ActivityAssignmentDemand__c
																	AND AAD._crda_isDeleted	= 0	
																	AND	AAD._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
						
		INNER JOIN	Kantata.HISTORY_Resource		R	ON	R.Id				= AA.KimbleOne__Resource__c
														AND	R._crda_isDeleted	= 0 
														AND	R._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

		LEFT JOIN	Kantata.HISTORY_ActivityRole	AR	ON  AR.Id				= AA.KimbleOne__ActivityRole__c
														AND AR._crda_isDeleted	= 0
														AND	AR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

		INNER JOIN	Kantata.HISTORY_ResourcedActivity	RA  ON  RA.Id			= AA.KimbleOne__ResourcedActivity__c
														    AND RA._crda_isDeleted	= 0
														    AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

		LEFT JOIN	Kantata.HISTORY_DeliveryGroup	DG	ON  DG.Id			= AA.KimbleOne__DeliveryGroup__c
														AND	DG._crda_isDeleted	= 0 
														AND	DG._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

		WHERE	AA._crda_isDeleted			= 0 
		AND		AA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
	) 
	SELECT
		 ActivityAssignmentBk 
		,ActivityAssignmentDemandBk 
		,ResourceBk	

		,DemandStart
		,DemandEnd	
		,DemandStartMonthEnd
		,DemandEndMonthEnd	

		,EarliestTimeEntryDate
		,LatestTimeEntryDate
		,ForecastP1EndDate	
		,ForecastP2EndDate	
		,ForecastP3EndDate

		,IncludeInRollUp	
		,ResourcedActivityBk	

		,ActivityAssgnRoleBk	
		,ActivityAssignmentDemandRole
		,ActivityRolePracticeBk	
		,CandidateStatusBk	

		,ResourceLocationBk		
		,ActivityLocationBk		
		,ActivityDeliveryGroupBk
		,DeliveryGroupAccountBk	
		,DeliveryGroupForecastStatusBk	
		,ActivityDemandStatusBk	
		,ResourcingStatusBk		
		,CurrencyIsoCode		
		,RevenueRate			

		,TotalActualCost	
		,ForecastP1Cost		
		,ForecastP2Cost		
		,ForecastP3Cost		

		,TotalActualRevenue	
		,ForecastP1Revenue	
		,ForecastP2Revenue	
		,ForecastP3Revenue	

		,TotalActualUsage	
		,ForecastP1Usage	
		,ForecastP2Usage	
		,ForecastP3Usage	

		,BaselineCost		
		,BaselineMargin		
		,BaselineMarginAmount 
		,BaselineRevenue	
		,BaselineUsage		
		,BaselineUtilisationPercentage	

		,AssignmentPercentage	
		,DefaultCostRatePercentage
		,DefaultRevenueRatePercentage	
		,DiscountPercentage		
		,UtilisationPercentage	

		,ResourcedActivityBusinessUnitBk
		,ResourcedActivityTypeBk	
		,ActivityGroup				
		,ResourceDeliveryElementBk	

		,DemandRef					
		,ActivityAssignmentLogNotes	

	FROM	cteDemandActivity 
	WHERE	RN = 1 ;



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

SELECT * FROM Internal.DemandActivity

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.DemandCapacity
AS 
		WITH cteConstants 
		AS (
			SELECT 
				current_timestamp() AS TimeNow,
				current_date() AS Today,
				ADD_MONTHS(current_date(), 36) AS FutureDate -- 3 years = 36 months 

		)
		, cteCURRENTrole
		AS( 
			SELECT
				 AA.ActivityAssignmentBk 
				,'CURRENTrole'						AS DemandCapacityType 
				,CAST(AA.DemandStart AS DATE)		AS PeriodStartDate	
				,CAST(AA.DemandEnd  AS DATE)		AS PeriodEndDate	
				,CAST(LAST_DAY(AA.DemandStart) AS DATE)	AS	PeriodStartMonthEnd
				,CAST(LAST_DAY(AA.DemandEnd)AS DATE)	AS	PeriodEndMonthEnd

				,AA.ResourceBk 
				,AA.ResourcedActivityBk 
				,AA.ActivityAssignmentDemandBk 
				,AA.ActivityDemandStatusBk 
				,AA.CandidateStatusBk 
				,AA.ActivityAssgnRoleBk 
				,AA.ActivityDeliveryGroupBk 
				,AA.DeliveryGroupAccountBk 
				,AA.ResourcedActivityBusinessUnitBk  
				,AA.ActivityDemandStatusBk			AS ReferenceDataBk	
				,AA.ResourcingStatusBk												

				,AA.UtilisationPercentage 

				,AA.TotalActualCost 
				,AA.ForecastP1Cost  
				,AA.ForecastP2Cost  
				,AA.ForecastP3Cost  

				,AA.TotalActualUsage 
				,AA.ForecastP1Usage 
				,AA.ForecastP2Usage 
				,AA.ForecastP3Usage 

				,AA.RevenueRate				AS ForecastRevenueRate	
				,AA.TotalActualRevenue 
				,AA.ForecastP1Revenue 
				,AA.ForecastP2Revenue 
				,AA.ForecastP3Revenue 
				,COALESCE(RD.Name, '')						AS Status		
				,COALESCE(EFE.KimbleOne__Probability__c , -9)	AS DeliveryElementProbability	
				,COALESCE(EFG.Name , '')					AS DeliveryGroupForecastStatusName

				,AA.DeliveryGroupForecastStatusBk 
				,AA.ResourceDeliveryElementBk 
				,AA.DemandRef
				,ROW_NUMBER() 
					OVER(
						PARTITION BY	AA.DemandRef 
						ORDER BY		HR.Name DESC, AA.DemandStart DESC
					)  AS xRN 

			FROM		Internal.demandactivity			AA	/*materialiased view*/
			LEFT JOIN	Kantata.HISTORY_Resource		HR	ON	HR.Id				= AA.ResourceBk  
															AND HR._crda_isDeleted	= 0
															AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	Kantata.HISTORY_ForecastStatus 	EFG	ON	EFG.Id				= AA.DeliveryGroupForecastStatusBk /*DeliveryGroup*/
															AND EFG._crda_isDeleted = 0
															AND	EFG._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	Kantata.HISTORY_ForecastStatus 	EFE	ON	EFE.Id				= AA.ResourceDeliveryElementBk   /*DeliveryElement*/
															AND EFE._crda_isDeleted = 0
															AND	EFE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			LEFT JOIN	Kantata.HISTORY_ReferenceData	RD	ON	RD.Id				= AA.ActivityDemandStatusBk 
															AND RD._crda_isDeleted	= 0
															AND	RD._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

			INNER JOIN cteConstants						C	ON	1=1 

			WHERE	COALESCE(AA.CandidateStatusBk , '')	<> 'a1RD0000002PmaqMAC'	/*Declined*/
			AND		(COALESCE(RD.Name, '') IN ('Open', 'Fulfilled') 
						OR	(
								COALESCE(RD.Name, '') ='CandidatesProposed'		/*a1RD0000002PmbIMAS*/
								AND LEFT(HR.Name,8) <> '#Generic'
							)
					)
			AND		COALESCE(RD.KimbleOne__Domain__c , '')= 'AssignmentDemandStatus'
			/*
			AND		NOT (
						COALESCE(HR.Name,'') LIKE '#Generic Associate%' 
							OR COALESCE(HR.Name,'') LIKE '#Generic Partner%' 
								OR COALESCE(HR.Name,'') LIKE '#Generic Nearshore%'
						) 20260517 ADO PR 829 #1169*/ 
				/*Exclude leavers*/	
			AND		COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, C.FutureDate)	> C.Today 
		) 
		, cteCleansedcteCURRENTrole
		AS( 
		
			SELECT
				 X.ActivityAssignmentBk 
				,X.DemandCapacityType	
				,X.PeriodStartDate 
				,X.PeriodEndDate 
				,X.PeriodStartMonthEnd 
				,X.PeriodEndMonthEnd 
				
				,X.ResourceBk 
				,X.ResourcedActivityBk 
				,X.ActivityAssignmentDemandBk 
				,X.ActivityDemandStatusBk 
				,X.CandidateStatusBk 
				,X.ActivityAssgnRoleBk 
				,X.ActivityDeliveryGroupBk 
				,X.DeliveryGroupAccountBk 
				,X.ResourcedActivityBusinessUnitBk  
				,X.ReferenceDataBk 		
				,X.ResourcingStatusBk	

				,X.DeliveryGroupForecastStatusBk 
				,X.ResourceDeliveryElementBk 

				,X.UtilisationPercentage 

				,X.TotalActualCost 
				,X.ForecastP1Cost  
				,X.ForecastP2Cost  
				,X.ForecastP3Cost  

				,X.TotalActualUsage 
				,X.ForecastP1Usage 
				,X.ForecastP2Usage 
				,X.ForecastP3Usage 

				,X.ForecastRevenueRate 
				,X.TotalActualRevenue 
				,X.ForecastP1Revenue 
				,X.ForecastP2Revenue 
				,X.ForecastP3Revenue 

				,X.DemandRef

			FROM(
				SELECT	* 
				FROM	cteCURRENTrole 
				WHERE	xRN = 1 
				AND		Status = 'Open'

				UNION ALL 

				SELECT	* 
				FROM	cteCURRENTrole 
				WHERE	Status = 'CandidatesProposed'

				UNION ALL

				SELECT	* 
				FROM	cteCURRENTrole 
				WHERE	Status			= 'Fulfilled'
				AND		DeliveryGroupForecastStatusName	<> '9. Lost (0%)' 
				AND		xRN = 1
				AND	NOT	(Status = 'Fulfilled' AND DeliveryElementProbability = 100) 
			) X 
			INNER JOIN cteConstants						C	ON	1=1 
			WHERE	X.PeriodEndDate >= C.Today  
		) 
		,cteFUTURErole
		AS ( 
			SELECT
				 AA.ActivityAssignmentBk 
				,'FUTURErole'							AS DemandCapacityType					
				,CAST(AA.DemandStart AS DATE)			AS PeriodStartDate			
				,CAST(AA.DemandEnd  AS DATE)			AS PeriodEndDate	
				,CAST(LAST_DAY(AA.DemandStart) AS DATE)	AS	PeriodStartMonthEnd
				,CAST(LAST_DAY(AA.DemandEnd)AS DATE)	AS	PeriodEndMonthEnd

				,AA.ResourceBk 
				,AA.ResourcedActivityBk 
				,AA.ActivityAssignmentDemandBk 
				,AA.ActivityDemandStatusBk 
				,AA.CandidateStatusBk 
				,AA.ActivityAssgnRoleBk	
				,AA.ActivityDeliveryGroupBk 
				,AA.DeliveryGroupAccountBk 
				,AA.ResourcedActivityBusinessUnitBk  
				,AA.ActivityDemandStatusBk			AS ReferenceDataBk			
				,AA.ResourcingStatusBk												

				,AA.DeliveryGroupForecastStatusBk 
				,AA.ResourceDeliveryElementBk 

				,AA.UtilisationPercentage 

				,AA.TotalActualCost 
				,AA.ForecastP1Cost  
				,AA.ForecastP2Cost  
				,AA.ForecastP3Cost  

				,AA.TotalActualUsage 
				,AA.ForecastP1Usage 
				,AA.ForecastP2Usage 
				,AA.ForecastP3Usage 

				,AA.RevenueRate						AS ForecastRevenueRate
				,AA.TotalActualRevenue 
				,AA.ForecastP1Revenue 
				,AA.ForecastP2Revenue 
				,AA.ForecastP3Revenue 

				,AA.DemandRef 


			FROM	Internal.demandactivity		AA	/* materialised view */

			INNER JOIN	Kantata.HISTORY_Resource	HR	ON	HR.Id				= AA.ResourceBk  
														AND HR._crda_isDeleted	= 0
														AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN cteConstants						C	ON	1=1 

			WHERE	AA.UtilisationPercentage > 0
			AND		COALESCE(AA.ResourcedActivityTypeBk,'')		= 'a1ZD0000000hnnuMAA'	/*Delivery*/ 
			AND		COALESCE(AA.CandidateStatusBk,'')				<> 'a1RD0000002PmaqMAC'	/*Declined*/ 
			AND		COALESCE(AA.DeliveryGroupForecastStatusBk, '')<> 'a0nD0000001yjIiIAI'	/*9. Lost (0%)*/ 
				/*Roles that haven't started yet*/ 
			AND		AA.DemandStart >= C.Today  
				/*Exclude leavers*/	
			AND		COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, C.FutureDate)	> C.Today 
		) 
		, cteNoDemandRef
		AS ( 
			SELECT
				 AA.ActivityAssignmentBk 
				,'NoDemandRef'							AS DemandCapacityType	
				,CAST(AA.DemandStart AS DATE)			AS PeriodStartDate	
				,CAST(AA.DemandEnd  AS DATE)			AS PeriodEndDate	
				,CAST(LAST_DAY(AA.DemandStart) AS DATE)	AS	PeriodStartMonthEnd
				,CAST(LAST_DAY(AA.DemandEnd)AS DATE)	AS	PeriodEndMonthEnd
				
				,AA.ResourceBk 
				,AA.ResourcedActivityBk 
				,AA.ActivityAssignmentDemandBk 
				,AA.ActivityDemandStatusBk 
				,AA.CandidateStatusBk 
				,AA.ActivityAssgnRoleBk	
				,AA.ActivityDeliveryGroupBk 
				,AA.DeliveryGroupAccountBk 
				,AA.ResourcedActivityBusinessUnitBk  
				,AA.ActivityDemandStatusBk				AS ReferenceDataBk	
				,AA.ResourcingStatusBk		

				,AA.DeliveryGroupForecastStatusBk 
				,AA.ResourceDeliveryElementBk 

				,AA.UtilisationPercentage 

				,AA.TotalActualCost 
				,AA.ForecastP1Cost  
				,AA.ForecastP2Cost  
				,AA.ForecastP3Cost  

				,AA.TotalActualUsage 
				,AA.ForecastP1Usage 
				,AA.ForecastP2Usage 
				,AA.ForecastP3Usage 

				,AA.RevenueRate							AS ForecastRevenueRate
				,AA.TotalActualRevenue 
				,AA.ForecastP1Revenue 
				,AA.ForecastP2Revenue 
				,AA.ForecastP3Revenue 

				,AA.DemandRef 


			FROM	Internal.demandactivity			AA	/* materialised view */

			INNER JOIN	Kantata.HISTORY_Resource	HR	ON	HR.Id				= AA.ResourceBk  
														AND HR._crda_isDeleted	= 0
														AND	HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN	Kantata.HISTORY_DeliveryElement	DE	ON	DE.Id				= AA.ResourceDeliveryElementBk  
															AND DE._crda_isDeleted	= 0
															AND	DE._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

			INNER JOIN cteConstants						C	ON	1=1 

			WHERE	AA.DemandRef IS NULL
			AND		DE.KimbleOne__Reference__c IS NOT NULL 
			AND		COALESCE(AA.CandidateStatusBk,'')				<> 'a1RD0000002PmaqMAC'	/*Declined*/ 
			AND		NOT (
						COALESCE(HR.Name,'') LIKE '#Generic Associate%' 
							OR COALESCE(HR.Name,'') LIKE '#Generic Partner%' 
								OR COALESCE(HR.Name,'') LIKE '#Generic Nearshore%'
						) 
				/*Exclude leavers*/	
			AND		COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, C.FutureDate)	> C.Today 
		) 
		SELECT * FROM cteCleansedcteCURRENTrole 
		UNION ALL 
		SELECT * FROM cteFUTURErole 
		UNION ALL 
		SELECT * FROM cteNoDemandRef 



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT * FROM Internal.DemandCapacity ;

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
