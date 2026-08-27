CREATE  
	FUNCTION Internal.FN_GetExplodeActiveDatesForResource(
		@PastDate DATE ,
		@FutureDate DATE 
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20250820	Mazhar			Initial Version

Returns a list of exploded out workday only dates that cover the 
active employment period for each Resource taking into consideration the 
input paramaters.

DECLARE @TimeNow	DATETIME2= GETUTCDATE() ;
DECLARE	@PastDate	DATE ; 
DECLARE	@FutureDate	DATE ; 

SELECT	@PastDate	= PastDate ,
		@FutureDate	= FutureDate
FROM	Tools.FN_GetPastAndFutureDates (-3, 2);
SELECT * FROM Internal.FN_GetExplodeActiveDatesForResource (@PastDate, @FutureDate)
ORDER BY ResourceBk, PeriodStart ;
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	SELECT	EmploymentStart = BU.DateFrom,
			PeriodStart		= DD.[Date] , 
			PeriodStartSk	= DD.DateKey , 
			BU.ResourceBk 
	FROM	Internal.DimDate		DD 
	CROSS APPLY ( 
		SELECT	ResourceBk	= HR.Id,
				DateFrom	= CAST(MAX(HR.KimbleOne__StartDate__c) AS DATE),
				DateTo		= CAST(MAX(COALESCE(HR.Provisional_End_Date__c, HR.KimbleOne__EndDate__c,@FutureDate)) AS DATE)
		FROM	lh_SilverLayer.Kantata.HISTORY_Resource	HR	
		WHERE	HR._crda_isDeleted = 0 
		AND		HR._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
		--AND		HR.Id = 'a1X8e000001foz4EAA'
		GROUP BY 
			HR.Id 
	)	BU 
	WHERE	DD.IsNonWorkDay = 0 
	AND		DD.[Date] >= @PastDate AND DD.[Date] <= BU.DateTo ;