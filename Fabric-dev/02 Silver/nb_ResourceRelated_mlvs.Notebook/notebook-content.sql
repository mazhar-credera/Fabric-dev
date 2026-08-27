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

ALTER TABLE Kantata.HISTORY_PerformanceAnalysis SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_AnalysisDimension   SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_TimePeriod          SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_AnalysisFact        SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_BusinessUnit        SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_PeriodType          SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ResourcedActivity   SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Resource            SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ResourcePeriod      SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ResourceHistory     SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Account             SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ForecastTimeEntry   SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_ActivityAssignment  SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
ALTER TABLE Kantata.HISTORY_Account             SET TBLPROPERTIES (delta.enableChangeDataFeed = true);


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************


CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.ResourceMonthlyTargetDays  
AS


WITH cteCrederaUKBu
AS (
	SELECT	Id  AS CrederaUKBu 
	FROM	Kantata.HISTORY_BusinessUnit 
	WHERE	`Name` = 'Credera UK' 
	AND		_crda_ActiveToDateTime = '9999-12-31 23:59:59' 
	AND		_crda_isDeleted = 0 

) , cteRsrcDays 
AS (
	/*Resource3Target 
	VIEW Kimble.vw_Resource3_DaysSummary - Target_AllDays*/
	SELECT	 CAST(TP.KimbleOne__StartDate__c AS DATE)	AS PeriodStartDate	
			,CAST(TP.KimbleOne__EndDate__c	 AS DATE)	AS PeriodEndDate		
			,COALESCE(BU.Id , B.CrederaUKBu ) AS BusinessUnitBk		
			,AD.`Name`						AS AnalysisDimension	
			,CASE 
							/* NumberOfBusinessDays				Company*/ 
				WHEN AF.Id = 'a0ED000000tiX3pMAE' AND AD.Id IN ('a0DD000000B4H56MAF') 
					THEN	'TargetBusinessDays'
							/* NumberOfOtherDays				Company*/ 
				WHEN AF.Id = 'a0E3z00000tbtJAEAY' AND AD.Id IN ('a0DD000000B4H56MAF') 
					THEN	'TargetOtherDays'
							/* NumberOfHolidayDays				Business Unit*/ 
				WHEN AF.Id = 'a0E3z00000ve7fXEAQ' AND AD.Id IN ('a0DD000000ia99sMAA') 
					THEN	'TargetHolidaysDays'
							/* NumberOfTrainingDays				Company*/ 
				WHEN AF.Id = 'a0E3z00000ve7fSEAQ' AND AD.Id IN ('a0DD000000B4H56MAF') 
					THEN	'TargetTrainingDays'
				ELSE 
					NULL 
			END													 AS AnalysisFact 
			,CAST(PA.KimbleOne__TargetAmount__c	AS DECIMAL(9,2)) AS TargetAmount 

	FROM		Kantata.HISTORY_PerformanceAnalysis	PA  

	INNER JOIN	Kantata.HISTORY_AnalysisDimension	AD 	ON  AD.Id	= PA.KimbleOne__AnalysisDimension__c
														AND AD._crda_isDeleted			= 0
														AND	AD._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

	INNER JOIN	Kantata.HISTORY_AnalysisFact		AF  ON	AF.Id	= PA.KimbleOne__AnalysisFact__c
														AND AF._crda_isDeleted			= 0
														AND	AF._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

	INNER JOIN	Kantata.HISTORY_TimePeriod		TP 	ON  TP.Id	= PA.KimbleOne__TimePeriod__c
													AND TP._crda_isDeleted			= 0 
													AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59'

	LEFT JOIN	Kantata.HISTORY_BusinessUnit		BU	ON	BU.Id		= PA.KimbleOne__BusinessUnit__c 
														AND BU._crda_isDeleted			= 0 
														AND	BU._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
	
	INNER JOIN	cteCrederaUKBu						B	ON	1=1 

	WHERE		(
					(
						AF.Id IN (	'a0E3z00000tbtJAEAY' /*'NumberOfOtherDays'*/ ,
									'a0E3z00000ve7fSEAQ' /*'NumberOfTrainingDays'*/ ,
									'a0E3z00000ve7fXEAQ' /*'NumberOfHolidayDays'*/ ,
									'a0ED000000tiX3pMAE' /*'NumberOfBusinessDays'*/ )
							
						AND AD.Id IN(
										'a0DD000000B4H56MAF', /*Company*/
										'a0DD000000ia99sMAA'  /*Business Unit*/
									)
					)
				) 
	AND			PA._crda_isDeleted = 0 
	AND			PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59'
) ,cteResourceMonthlyTargetDays
AS (
    SELECT 
        CAST(PeriodStartDate AS DATE) AS PeriodStartDate,
        CAST(PeriodEndDate AS DATE) AS PeriodEndDate,
        COALESCE(BusinessUnitBk, 'UnknownRecord') AS BusinessUnitBk,
        -- Manual Pivot using Conditional Aggregation
        SUM(CASE WHEN AnalysisFact = 'TargetBusinessDays' THEN TargetAmount ELSE 0 END) AS TargetBusinessDays,
        SUM(CASE WHEN AnalysisFact = 'TargetTrainingDays' THEN TargetAmount ELSE 0 END) AS TargetTrainingDays,
        SUM(CASE WHEN AnalysisFact = 'TargetHolidaysDays' THEN TargetAmount ELSE 0 END) AS TargetHolidaysDays,
        SUM(CASE WHEN AnalysisFact = 'TargetOtherDays'    THEN TargetAmount ELSE 0 END) AS TargetOtherDays,
        ROW_NUMBER() OVER (
            PARTITION BY PeriodStartDate, COALESCE(BusinessUnitBk, 'UnknownRecord')
            ORDER BY PeriodStartDate
        ) AS RN
    FROM cteRsrcDays
    GROUP BY 
        PeriodStartDate, 
        PeriodEndDate, 
        BusinessUnitBk
) 
SELECT
	 T.PeriodStartDate 
	,T.PeriodEndDate 
	,T.BusinessUnitBk 
	,T.TargetBusinessDays
	,T.TargetTrainingDays 
	,T.TargetHolidaysDays
	,T.TargetOtherDays 

FROM	cteResourceMonthlyTargetDays T  
WHERE	T.RN = 1 


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

SELECT * FROM Internal.ResourceMonthlyTargetDays

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.ResourceUsage  
AS


WITH cteSrc
AS( 
	SELECT	 PA.KimbleOne__Resource__c					AS ResourceBk
			,CAST(TP.KimbleOne__StartDate__c AS DATE)	AS PeriodStartDate	
			,CAST(TP.KimbleOne__EndDate__c AS DATE)		AS PeriodEndDate	
			,PA.Id										AS PerformanceAnalysisBk	
			,PA.KimbleOne__Account__c					AS AccountBk	
			,RA.KimbleOne__ResourcedActivityType__c		AS ResourcedActivityTypeBk 
			,PA.KimbleOne__AnalysisFact__c				AS AnalysisFactBk	
			,PA.KimbleOne__DeliveryGroup__c				AS DeliveryGroupBk	
			,RA.KC_DMW_Activity_Type__c					AS DmwActivityType		
			,RA.DisplayName__c							AS ResourcedActivityDisplayName	 
			,PA.KimbleOne__BusinessUnit__c				AS PaBusinessUnitBk	 

			,PA.KimbleOne__DeliveryElement__c			AS DeliveryElementBk
			,RH.Practice__c								AS PracticeBk	
			,RH.KimbleOne__Grade__c						AS GradeBk	

			,AC.KimbleOne__BusinessUnit__c				AS AccountBusinessUnitBk
			,RH.KimbleOne__BusinessUnit__c				AS ResourceBusinessUnitBk

			,CAST(COALESCE(PA.KimbleOne__P1ForecastAmount__c, 0)AS DECIMAL(18,2)) AS P1ForecastAmount
			,CAST(COALESCE(PA.KimbleOne__P2ForecastAmount__c, 0)AS DECIMAL(18,2)) AS P2ForecastAmount
			,CAST(COALESCE(PA.KimbleOne__P3ForecastAmount__c, 0)AS DECIMAL(18,2)) AS P3ForecastAmount

			,ROW_NUMBER() 	/*PK/Unique constraints are not enforced so...*/
				OVER (
					PARTITION BY	PA.KimbleOne__Resource__c, TP.KimbleOne__StartDate__c, PA.Id  
					ORDER BY		PA.KimbleOne__Resource__c, TP.KimbleOne__StartDate__c 
				) AS RN 
			,PA._crda_ActiveFromDateTime 

	FROM		Kantata.HISTORY_PerformanceAnalysis	PA

	INNER JOIN	Kantata.HISTORY_TimePeriod	TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
												AND	TP._crda_isDeleted			= 0 
												AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

	INNER JOIN	Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
												AND PT._crda_isDeleted			= 0
												AND	PT.Name					= 'Month'
												AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

	INNER JOIN	Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id						= PA.KimbleOne__ResourcedActivity__c
														AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
														AND	RA._crda_isDeleted			= 0

	INNER JOIN 	Kantata.HISTORY_Resource		RO	ON	RO.Id						= PA.KimbleOne__Resource__c 
													AND	RO._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	RO._crda_isDeleted			= 0

	LEFT JOIN	Kantata.HISTORY_ResourcePeriod	RP	ON	RP.Id					= PA.KimbleOne__ResourcePeriod__c 
													AND	RP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	RP._crda_isDeleted			= 0

	LEFT JOIN	Kantata.HISTORY_ResourceHistory	RH	ON	RH.Id						= RP.KimbleOne__ResourceHistory__c 
													AND	RH._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	RH._crda_isDeleted			= 0


	LEFT JOIN Kantata.HISTORY_Account	AC	ON	AC.Id						= PA.KimbleOne__Account__c 
											AND	AC._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
											AND	AC._crda_isDeleted			= 0

	WHERE	PA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
			/* Filter just ResourceUsage Records */
	AND		PA.KimbleOne__AnalysisFact__c	IN	('a0ED000000CxJIzMAN',  /*ResourceUsage*/ 
												 'a0ED000000CxJJ0MAN')	/*FactoredResourceUsage*/ 
	AND		PA._crda_isDeleted = 0
) 
SELECT  
	 SRC.ResourceBk
	,SRC.PeriodStartDate
	,SRC.PeriodEndDate
	,SRC.PerformanceAnalysisBk 
	,SRC.AccountBk
	,SRC.AnalysisFactBk
	,SRC.ResourcedActivityTypeBk
	,SRC.DeliveryGroupBk
	,SRC.DeliveryElementBk
	,SRC.DmwActivityType 
	,SRC.ResourcedActivityDisplayName 
	,SRC.PaBusinessUnitBk

	,SRC.PracticeBk
	,SRC.GradeBk
	,SRC.AccountBusinessUnitBk
	,SRC.ResourceBusinessUnitBk
	,SRC.P1ForecastAmount
	,SRC.P2ForecastAmount
	,SRC.P3ForecastAmount 
	,SRC._crda_ActiveFromDateTime 

FROM	cteSrc SRC 
WHERE	SRC.RN = 1 ; 



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": false,
-- META   "editable": true
-- META }

-- CELL ********************

SELECT * FROM Internal.ResourceUsage 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.ResourceAbsence  
AS


	WITH cteConstants
	AS(
		SELECT 
			 -24 AS NoOfMonths
			,2	 AS NoOfYears 

	) ,cteConstantsv2
	AS(
		SELECT 
			current_timestamp()										AS TimeNow,
			-- Calculate PastDate: First of current month minus 24 months
			add_months(trunc(current_date(), 'MM'), C.NoOfMonths)	AS PastDate,
			-- Calculate FutureDate: First of current month plus 2 years (24 months)
			add_months(trunc(current_date(), 'MM'), C.NoOfYears * 12) AS FutureDate
		FROM cteConstants C	
    ), cteDateRange 
	AS (
	  SELECT 
		to_date('2000-01-01') AS start_date,
		to_date('2050-12-31') AS end_date
    ), cteDimDates 
    AS (
    SELECT 
        explode(sequence(start_date, end_date, interval 1 day)) AS calendar_date
    FROM cteDateRange
    ),
    cteResourceSummary 
    AS (
        SELECT 
            HR.Id AS ResourceBk,
            CAST(MAX(HR.KimbleOne__StartDate__c) AS DATE) AS DateFrom,
            CAST(MAX(COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c, C.FutureDate)) AS DATE) AS DateTo
        FROM Kantata.HISTORY_Resource   HR
        INNER JOIN	cteConstantsv2	    C	ON 1 = 1 
        WHERE HR._crda_isDeleted = 0 
        AND HR._crda_ActiveToDateTime = '9999-12-31 23:59:59'
        GROUP BY HR.Id
    ),cteExpladeResourceActiveDates 
    AS (
    SELECT 
        BU.DateFrom AS EmploymentStart,
        DD.calendar_date AS PeriodStart,
        BU.DateTo,
        BU.ResourceBk
    FROM cteDimDates DD
    INNER JOIN cteResourceSummary BU 
        ON DD.calendar_date >= BU.DateFrom 
        AND DD.calendar_date <= BU.DateTo
    ), cteResourceAbsence
	AS( 
		SELECT
			 T.KimbleOne__Resource__c					AS ResourceBk		
			,CAST(TP.KimbleOne__StartDate__c AS DATE)	AS AbsenceDate	
			,T.KimbleOne__EntryUnits__c					AS HolidayHours	
			,T._crda_ActiveFromDateTime 

		FROM		Kantata.HISTORY_ForecastTimeEntry	T  

		INNER JOIN	cteConstantsv2						C	ON 1 = 1 

		LEFT JOIN	Kantata.HISTORY_ActivityAssignment	AA 	ON	AA.Id				= T.KimbleOne__ActivityAssignment__c
															AND AA._crda_isDeleted	= 0 
															AND	AA._crda_ActiveToDateTime = '9999-12-31 23:59:59'

		INNER JOIN	Kantata.HISTORY_TimePeriod	TP 	ON	TP.Id				= T.KimbleOne__TimePeriod__c 
													AND TP._crda_isDeleted	= 0 
													AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
													AND	TP.KimbleOne__PeriodType__c = 'a1DD0000000UHKsMAO'	/*BusDay*/

		LEFT JOIN	Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id				= AA.KimbleOne__ResourcedActivity__c
															AND RA._crda_isDeleted	= 0 
															AND	RA._crda_ActiveToDateTime = '9999-12-31 23:59:59' 
															AND	RA.Activity_Group__c IN  ('Absence', 'People') 

		WHERE	T._crda_ActiveFromDateTime > C.PastDate   
		AND		T._crda_ActiveToDateTime = '9999-12-31 23:59:59'
		AND		T._crda_isDeleted = 0  
		AND		CAST(TP.KimbleOne__StartDate__c AS DATE) BETWEEN C.PastDate AND C.FutureDate 
	) , cteIdentifyGaps
	AS(
		SELECT	 F.ResourceBk, F.PeriodStart, RR.AbsenceDate
				,RR.HolidayHours
				,CASE WHEN RR.AbsenceDate IS NOT NULL THEN 1 ELSE 0 END AS IsAbsence 
				,ROW_NUMBER() 
						OVER( 
							PARTITION BY F.ResourceBk
							ORDER BY	 F.PeriodStart
						)				AS RN 
				,ROW_NUMBER() 
						OVER( 
							PARTITION BY F.ResourceBk , CASE WHEN RR.AbsenceDate IS NOT NULL THEN 1 ELSE 0 END 
							ORDER BY	 F.PeriodStart
						)				AS Gaps 

		FROM	cteExpladeResourceActiveDates F 
		LEFT JOIN (
					SELECT	 R.ResourceBk
							,R.AbsenceDate 
							,SUM(R.HolidayHours)	AS HolidayHours	
					FROM	cteResourceAbsence R 
					--WHERE	ResourceBk = 'a1X3z000003Qsx9EAC' 
					GROUP BY ResourceBk, AbsenceDate
		)		RR	ON	RR.ResourceBk	= F.ResourceBk 
					AND	RR.AbsenceDate	= F.PeriodStart 
		/*			AND	R.ResourceBk IN ('a1X8e000001foz4EAA', 'a1X4K000000K8xfUAC' )
		WHERE	F.ResourceBk IN ('a1X8e000001foz4EAA', 'a1X4K000000K8xfUAC' ) */
	), cteIdentifyIslandsOfAbsences
	AS(
		SELECT	F.ResourceBk, F.PeriodStart, F.AbsenceDate 
                ,F.HolidayHours, F.IsAbsence, F.RN, F.Gaps 
				,RN-Gaps    AS Islands
		FROM	cteIdentifyGaps F
		WHERE	F.IsAbsence = 1
	), cteData 
	AS (
		SELECT	
			 I.ResourceBk 
			,MIN(I.AbsenceDate) AS AbsenceStartDate	
			,MAX(I.AbsenceDate) AS AbsenceEndDate	
			,SUM(I.HolidayHours/8)  AS NumberOfDays 
		FROM	cteIdentifyIslandsOfAbsences I 
		GROUP BY I.ResourceBk , I.Islands 
	) , cteRN 
	AS(
		SELECT	
			 ResourceBk 
			,AbsenceStartDate
			,AbsenceEndDate	
			,CAST(I.NumberOfDays AS DECIMAL(5,2))   AS NumberOfDays  
			,ROW_NUMBER()		/*PK/Unique constraints are not enforced so...*/ 
					OVER (
						PARTITION BY	ResourceBk, AbsenceStartDate
						ORDER BY		AbsenceStartDate  
					)	AS RN 
		FROM	cteData I 
	) 
	SELECT	
		 ResourceBk 
		,AbsenceStartDate
		,AbsenceEndDate	
		,NumberOfDays	
	FROM 	cteRN
	WHERE	RN = 1 ;



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT * FROM Internal.ResourceAbsence  

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }

-- CELL ********************

CREATE OR REPLACE MATERIALIZED LAKE VIEW Internal.ResourceAccountHistory  
AS


	WITH cteResourceAccountHistory 
	AS(
		SELECT	 
			 PA.Id								AS PerformanceAnalysisBk
			,PA.KimbleOne__Resource__c			AS ResourceBk			
			,PA.KimbleOne__TimePeriod__c		AS TimePeriodBk		
			,COALESCE(PA.KimbleOne__Account__c , 'UnknownRecord')  AS AccountBk	
			,CAST(TP.KimbleOne__StartDate__c AS DATE)		AS PeriodStartDate
			,CAST(TP.KimbleOne__EndDate__c AS DATE)			AS PeriodEndDate	

			/*ForecastRevenue*/
			,NULL								AS P1ForecastRevenue
			,NULL								AS P2ForecastRevenue
			,NULL								AS P3ForecastRevenue

			/*ResourceUsage*/
			,IF(AF.Id = 'a0ED000000CxJIzMAN', PA.KimbleOne__P1ForecastResourceUsageDelivery__c, 0 )  AS P1ForecastResourceUsageDelivery
			,IF(AF.Id = 'a0ED000000CxJIzMAN', PA.KimbleOne__P2ForecastResourceUsageDelivery__c, 0 )  AS P2ForecastResourceUsageDelivery
			,IF(AF.Id = 'a0ED000000CxJIzMAN', PA.KimbleOne__P3ForecastResourceUsageDelivery__c, 0 )  AS P3ForecastResourceUsageDelivery
					
			/*FactoredResourceUsage*/	
			,IF(AF.Id = 'a0ED000000CxJJ0MAN', PA.KimbleOne__P1ForecastResourceUsageDelivery__c, 0 ) AS FactoredP1ForecastResourceUsageDelivery	
			,IF(AF.Id = 'a0ED000000CxJJ0MAN', PA.KimbleOne__P2ForecastResourceUsageDelivery__c, 0 ) AS FactoredP2ForecastResourceUsageDelivery	 
			,IF(AF.Id = 'a0ED000000CxJJ0MAN', PA.KimbleOne__P3ForecastResourceUsageDelivery__c, 0 ) AS FactoredP3ForecastResourceUsageDelivery	 

			,'ResourceDelivUsage'				AS RecordType
			,ROW_NUMBER() 
					OVER (
						PARTITION BY	PA.Id, CAST(TP.KimbleOne__StartDate__c AS DATE)
						ORDER BY		PA.Id, CAST(TP.KimbleOne__StartDate__c AS DATE)  
					)						AS RN 

		FROM		Kantata.HISTORY_PerformanceAnalysis	PA 

		INNER JOIN Kantata.HISTORY_AnalysisFact	AF	ON	AF.Id = PA.KimbleOne__AnalysisFact__c 
													AND	AF.Id IN (	/*'ResourceUsage', 'FactoredResourceUsage'*/
																	'a0ED000000CxJIzMAN', 'a0ED000000CxJJ0MAN'
																	) 
													AND	AF._crda_isDeleted			= 0 
													AND	AF._crda_ActiveToDateTime = '9999-12-31 23:59:59'

		INNER JOIN	Kantata.HISTORY_TimePeriod	TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
													AND	TP._crda_isDeleted			= 0 
													AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

		INNER JOIN	Kantata.HISTORY_PeriodType	PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
													AND PT._crda_isDeleted			= 0
													AND	PT.`Name`					= 'Month'
													AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

		WHERE	PA._crda_isDeleted			= 0 
		AND		PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
		AND		PA.KimbleOne__Resource__c	IS NOT NULL 

		UNION ALL 

		SELECT	 
			 PA.Id									AS PerformanceAnalysisBk
			,PA.KimbleOne__Resource__c				AS ResourceBk			
			,PA.KimbleOne__TimePeriod__c			AS TimePeriodBk		
			,COALESCE(PA.KimbleOne__Account__c , 'UnknownRecord')  AS AccountBk			
			,CAST(TP.KimbleOne__StartDate__c AS DATE)AS PeriodStartDate	
			,CAST(TP.KimbleOne__EndDate__c AS DATE)	AS PeriodEndDate		

				/*ForecastRevenue*/
			,PA.KimbleOne__CorporateCurrencyP1ForecastRevenueCalc	AS P1ForecastRevenue	
			,PA.KimbleOne__CorporateCurrencyP2ForecastRevenueCalc	AS P2ForecastRevenue	
			,PA.KimbleOne__CorporateCurrencyP3ForecastRevenueCalc	AS P3ForecastRevenue	

				/*ResourceUsage*/
			,NULL									AS P1ForecastResourceUsageDelivery	
			,NULL									AS P2ForecastResourceUsageDelivery	
			,NULL									AS P3ForecastResourceUsageDelivery	

				/*FactoredResourceUsage*/
			,NULL									AS FactoredP1ForecastResourceUsageDelivery	
			,NULL									AS FactoredP2ForecastResourceUsageDelivery	
			,NULL									AS FactoredP3ForecastResourceUsageDelivery	

			,'ForecastRevenue'						AS RecordType
			,ROW_NUMBER() 
					OVER (
						PARTITION BY	PA.Id, CAST(TP.KimbleOne__StartDate__c AS DATE)
						ORDER BY		PA.Id, CAST(TP.KimbleOne__StartDate__c AS DATE)  
					)						AS RN 

		FROM		Kantata.HISTORY_PerformanceAnalysis	PA 

		INNER JOIN	Kantata.HISTORY_TimePeriod			TP 	ON  TP.Id						= PA.KimbleOne__TimePeriod__c 
															AND	TP._crda_isDeleted			= 0 
															AND	TP._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

		INNER JOIN	Kantata.HISTORY_PeriodType			PT	ON	PT.Id						= TP.KimbleOne__PeriodType__c 
															AND PT._crda_isDeleted			= 0
															AND	PT._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
															AND	PT.`Name`					= 'Month'

		WHERE	PA._crda_isDeleted			= 0 
		AND		PA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
		AND		PA.KimbleOne__Resource__c	IS NOT NULL  
		AND		PA.KimbleOne__AnalysisFact__c	IN ('a0E3z00000uZEf6EAG',	/*RevenueInternal*/
													'a0E3z00000uZEf7EAG',	/*CostInternal	 */
													'a0ED000000CxJIuMAN',	/*Revenue		 */
													'a0ED000000CxJIvMAN')	/*Cost			 */
		) 
		SELECT  
			 SRC.PerformanceAnalysisBk
			,SRC.ResourceBk
			,SRC.AccountBk
			,SRC.TimePeriodBk
			,SRC.PeriodStartDate
			,SRC.PeriodEndDate 

			,SRC.P1ForecastResourceUsageDelivery
			,SRC.P2ForecastResourceUsageDelivery
			,SRC.P3ForecastResourceUsageDelivery

			,SRC.FactoredP1ForecastResourceUsageDelivery
			,SRC.FactoredP2ForecastResourceUsageDelivery
			,SRC.FactoredP3ForecastResourceUsageDelivery

			,SRC.P1ForecastRevenue
			,SRC.P2ForecastRevenue
			,SRC.P3ForecastRevenue
			,SRC.RecordType

		FROM	cteResourceAccountHistory	SRC 
		WHERE	SRC.RN = 1 



-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

SELECT * FROM Internal.ResourceAccountHistory ; 

-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark",
-- META   "frozen": true,
-- META   "editable": false
-- META }
