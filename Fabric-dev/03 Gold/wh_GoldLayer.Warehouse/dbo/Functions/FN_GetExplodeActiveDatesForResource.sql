CREATE --OR ALTER
	FUNCTION dbo.FN_GetExplodeActiveDatesForResource(
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
FROM	dbo.FN_GetPastAndFutureDates (-3, 2);
SELECT * FROM dbo.FN_GetExplodeActiveDatesForResource (@PastDate, @FutureDate);
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	SELECT	EmploymentStart = BU.DateFrom,
			PeriodStart		= DD.[Date] , 
			PeriodStartSk	= DD.DateSk , 
			BU.ResourceSk , 
			BU.ResourceBk 
	FROM	dbo.DimDate		DD 
	CROSS APPLY ( 
		SELECT	D.ResourceSk , D.ResourceBk,
				DateFrom	= CAST(MAX(D.StartDate) AS DATE),
				DateTo		= CAST(MAX(COALESCE(D.ProvisionalEndDate, D.EndDate,@FutureDate)) AS DATE)
		FROM	dbo.DimResource	D
		WHERE	D.ResourceSk	> 1 
		AND		D.IsCurrent		= 1 
		--AND		B.ResourceBk = 'a1X8e000001foz4EAA'
		GROUP BY 
			D.ResourceSk , D.ResourceBk 
	)	BU 
	WHERE	DD.IsNonWorkDay = 0 
	AND		DD.[Date] >= @PastDate AND DD.[Date] <= BU.DateTo ;