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

	WITH cteAccountDates
	AS(
		SELECT	DA.AccountBk	AS cteAccountBk, 
				B2.AccountSk	AS AccountSk , 
				MIN(DATEFROMPARTS(YEAR(DA._crda_ActiveFromDate), MONTH(DA._crda_ActiveFromDate), 1)) AS ActiveFrom , 
				IIF(
						MAX(CAST(DA._crda_ActiveToDate AS DATE)) = '90001231',
						@FutureDate ,
						MAX(CAST(DA._crda_ActiveToDate AS DATE))
					)												AS ActiveTo 
		FROM	dbo.DimAccount DA 

		LEFT JOIN 
				(
					SELECT	B1.AccountBk, B1.AccountSk
					FROM	dbo.DimAccount B1 
					WHERE	B1.IsCurrent = 1 
				)	B2	ON	B2.AccountBk = DA.AccountBk 

		WHERE	DA.AccountSk > 1
		GROUP BY DA.AccountBk, B2.AccountSk 
	) 
	SELECT	[Date]				AS PeriodStart	, 
			DateSk				AS PeriodStartSk, 
			EOMONTH([Date])		AS PeriodEnd	, 
			CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT) AS PeriodEndSk, 
			BU.AccountSk		AS AccountSk 
	FROM	dbo.DimDate 
	CROSS APPLY cteAccountDates	BU 
	WHERE	DayNumberInMonth = 1 
	AND		[Date] >= BU.ActiveFrom AND [Date] <= BU.ActiveTo
	AND		[Date] <= @FutureDate ;