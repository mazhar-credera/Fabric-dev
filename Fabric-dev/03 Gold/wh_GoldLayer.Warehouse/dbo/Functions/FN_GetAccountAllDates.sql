CREATE   
	FUNCTION dbo.FN_GetAccountAllDates(
		@FutureDate DATE 
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20250507	Mazhar			Initial Version

Returns a list of Month Start and End Dates that cover the active period for each Account 

DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
DECLARE	@FutureDate	DATE = DATEADD(YEAR, 2, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 
SELECT * FROM dbo.FN_GetAccountAllDates (@FutureDate) ORDER BY AccountSk, PeriodStart;
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	SELECT	[Date]				AS PeriodStart	, 
			DateSk				AS PeriodStartSk, 
			EOMONTH([Date])		AS PeriodEnd	, 
			CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT) AS PeriodEndSk, 
			BU.AccountSk 
	FROM	dbo.DimDate 
	CROSS APPLY ( 
		SELECT	B.AccountBk, AccountSk = B2.AccountSk , 
				MIN(DATEFROMPARTS(YEAR(B._crda_ActiveFromDate), MONTH(B._crda_ActiveFromDate), 1)) AS ActiveFrom , 
				IIF(
						MAX(CAST(B._crda_ActiveToDate AS DATE)) = '90001231',
						@FutureDate ,
						MAX(CAST(B._crda_ActiveToDate AS DATE))
					)												AS ActiveTo 
		FROM	dbo.DimAccount B 
		LEFT JOIN (
			SELECT	B1.AccountBk, B1.AccountSk
			FROM	dbo.DimAccount B1 
			WHERE	B1.IsCurrent = 1 
		)	B2	ON	B2.AccountBk = B.AccountBk 
		WHERE B.AccountSk > 1
		GROUP BY 
			B.AccountBk, B2.AccountSk 
	)	BU 
	WHERE	DayNumberInMonth = 1 
	AND		[Date] >= BU.ActiveFrom AND [Date] <= BU.ActiveTo
	AND		[Date] <= @FutureDate ;