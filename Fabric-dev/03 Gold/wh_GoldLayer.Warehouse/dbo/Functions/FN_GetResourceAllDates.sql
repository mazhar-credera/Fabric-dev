CREATE --OR ALTER
	FUNCTION dbo.FN_GetResourceAllDates(
		@FutureDate DATE 
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20250507	Mazhar			Initial Version

Returns a list of Month Start and End Dates that cover the active period for each Resource.
DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
DECLARE	@FutureDate	DATE = DATEADD(YEAR, 2, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

SELECT * FROM dbo.FN_GetResourceAllDates (@FutureDate);
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	SELECT	PeriodStart		= DD.[Date] , 
			PeriodStartSk	= DD.DateSk , 
			PeriodEnd		= EOMONTH(DD.[Date]) , 
			PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH(DD.[Date]), 112) AS INT) , 
			BU.EmploymentStart,
			BU.ResourceSk , 
			BU.ResourceBk 
	FROM	dbo.DimDate		DD 
	CROSS APPLY ( 
		SELECT	B.ResourceBk, ResourceSk = B2.ResourceSk , 
				EmploymentStart	= CAST(MAX(B.StartDate) AS DATE),
				ActiveFrom		= MIN(DATEFROMPARTS(YEAR(B.StartDate), MONTH(B.StartDate), 1)) ,
				ActiveTo		= CAST(MAX(COALESCE(B.ProvisionalEndDate, B.EndDate, @FutureDate)) AS DATE)
		FROM	dbo.DimResource B 
		INNER JOIN (
			SELECT	B1.ResourceBk, B1.ResourceSk
			FROM	dbo.DimResource B1 
			WHERE	B1.IsCurrent = 1 
		)	B2	ON	B2.ResourceBk = B.ResourceBk 
		WHERE B.ResourceSk > 1
		--AND		B.ResourceBk = 'a1X8e000001foz4EAA'
		GROUP BY 
			B.ResourceBk, B2.ResourceSk 
	)	BU 
	WHERE	DD.DayNumberInMonth = 1 
	AND		DD.[Date] >= BU.ActiveFrom AND DD.[Date] <= BU.ActiveTo 
	AND		DD.[Date] <= @FutureDate ;