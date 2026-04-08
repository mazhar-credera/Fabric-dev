CREATE   
	FUNCTION Internal.FN_GetFutureDemandConfirmedOpps(
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20251204	Mazhar			Initial Version

Returns a list of confirmed Engagements (Opportunities (Opps)) that 
either start in the future or end in the future.

SELECT * FROM Internal.FN_GetFutureDemandConfirmedOpps ();
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	SELECT	 DemandStart			= CAST(AA.KimbleOne__StartDate__c AS DATE)
			,DemandEnd				= CAST(AA.KimbleOne__ForecastP3EndDate__c  AS DATE) 
			,ForecastP3EndDate		= CAST(AA.KimbleOne__ForecastP3EndDate__c  AS DATE) 
			,ResourcedActivityBk	= RA.Id 
			,ResourceBk				= AA.KimbleOne__Resource__c 
			,CandidateStatusBk		= AA.KimbleOne__CandidateStatus__c 
			,DeliveryGroupBk		= DG.Id 
			,DeliveryGroupAccountBk	= DG.KimbleOne__Account__c 
			,DG_ForecastStatusBk	= DG_FS.Id 
			,DG_FSProbability		= DG_FS.KimbleOne__Probability__c 
			,DeliveryElementBk		= DE.Id 
			,DE_FSForecastStatusBk	= DE_FS.Id 
			,UtilisationPercentage	= AA.KimbleOne__UtilisationPercentage__c 
			,RN = ROW_NUMBER()OVER
				(
					PARTITION BY	AA.KimbleOne__Resource__c 
					ORDER BY		IIF(AA.KimbleOne__CandidateStatus__c IS NOT NULL, 1, 0) DESC ,
									DE_FS.SortOrder DESC, 
									AA.KimbleOne__StartDate__c DESC
				) 
	FROM		(
					SELECT	RN=ROW_NUMBER()OVER
							(
								PARTITION BY	A.KimbleOne__Resource__c, A.KimbleOne__ResourcedActivity__c, A.KimbleOne__DeliveryGroup__c
								ORDER BY		A._crda_ActiveFromDateTime DESC 
							), *
					FROM	lh_SilverLayer.Kantata.HISTORY_ActivityAssignment A	
					WHERE	A._crda_isDeleted			= 0 
					AND		A._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				) AA 

	LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ResourcedActivity	RA	ON	RA.Id				= AA.KimbleOne__ResourcedActivity__c 
																		AND	AA.RN				= 1 
																		AND	RA._crda_isDeleted	= 0 
																		AND	RA._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

	LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_DeliveryGroup	DG	ON	DG.Id				= AA.KimbleOne__DeliveryGroup__c
																	AND	DG._crda_isDeleted	= 0 
																	AND	DG._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

	LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_ForecastStatus	DG_FS	ON	DG_FS.Id				= DG.KimbleOne__ForecastStatus__c
																		AND	DG_FS._crda_isDeleted	= 0 
																		AND	DG_FS._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

	LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_Resource		R	ON  R.Id				= AA.KimbleOne__Resource__c
																AND	R._crda_isDeleted	= 0 
																AND	R._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 

	LEFT JOIN	(
				SELECT	RN=ROW_NUMBER()OVER
						(
							PARTITION BY	D.KimbleOne__DeliveryGroup__c
							ORDER BY		D._crda_ActiveFromDateTime DESC 
						)
						,*
				FROM	lh_SilverLayer.Kantata.HISTORY_DeliveryElement D
				WHERE	D._crda_isDeleted			= 0 
				AND		D._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				)							DE	ON	DE.KimbleOne__DeliveryGroup__c = DG.Id
												AND	DE.RN = 1 

	LEFT JOIN	(
				SELECT	
					SortOrder	=
								CASE FS.[Name]
									WHEN '9. Lost (0%)'			THEN 0
									WHEN '1. Lead (1%)'			THEN 1
									WHEN '2. Qualify (10%)'		THEN 2
									WHEN '3. Solutions (25%)'	THEN 3
									WHEN '3. Possible (40%)'	THEN 3
									WHEN '4. Propose (50%)'		THEN 4 
									WHEN '4. Probable (60%)'	THEN 4
									WHEN '5. Negotiate (75%)'	THEN 5
									WHEN '6. Verbal Win (90%)'	THEN 6
									WHEN '7. Firm (100%)'		THEN 7
									WHEN 'Working at Risk (100%)'	THEN 7
								END 
						,*
				FROM	lh_SilverLayer.Kantata.HISTORY_ForecastStatus FS 
				WHERE	FS._crda_isDeleted			= 0 
				AND		FS._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
				)							DE_FS	ON	DE_FS.Id = DE.KimbleOne__ForecastStatus__c 


	WHERE		AA.[KimbleOne__UtilisationPercentage__c]			> 0 
	AND			ISNULL(AA.KimbleOne__CandidateStatus__c,'')			<> 'a1RD0000002PmaqMAC' /*Declined*/
	AND			ISNULL(RA.KimbleOne__ResourcedActivityType__c,'')	= 'a1ZD0000000hnnuMAA'  /*Delivery*/

	AND			(
					(AA.KimbleOne__StartDate__c >= R.KimbleOne__StartDate__c)
						AND	( AA.KimbleOne__StartDate__c >= CAST(GETDATE() AS DATE)
								OR 	(CAST(GETDATE() AS DATE)) BETWEEN AA.KimbleOne__StartDate__c AND AA.KimbleOne__ForecastP3EndDate__c
							) 
				) 
	AND			ISNULL(DG_FS.Id,'') <> 'a0nD0000001yjIiIAI' /*9. Lost (0%)*/