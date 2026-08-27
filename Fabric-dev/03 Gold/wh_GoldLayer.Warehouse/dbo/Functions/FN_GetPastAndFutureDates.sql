CREATE --OR ALTER
	FUNCTION dbo.FN_GetPastAndFutureDates (
		 @NoOfMonths	INT = -3
		,@NoOfYears		INT = 2 
)
/*
SELECT * FROM dbo.FN_GetPastAndFutureDates (-3, 2);
*/
RETURNS TABLE 
WITH SCHEMABINDING
AS
RETURN

	SELECT	X.TimeNow, PD.PastDate, FD.FutureDate
	FROM(
		SELECT TimeNow	= GETUTCDATE()
	) X
	CROSS APPLY(
		SELECT	PastDate	= DATEADD(MONTH, @NoOfMonths, DATEFROMPARTS(YEAR(X.TimeNow), MONTH(X.TimeNow), 1))
	) PD
	CROSS APPLY(
		SELECT FutureDate	= DATEADD(YEAR, @NoOfYears, DATEFROMPARTS(YEAR(X.TimeNow), MONTH(X.TimeNow), 1))
	) FD ;