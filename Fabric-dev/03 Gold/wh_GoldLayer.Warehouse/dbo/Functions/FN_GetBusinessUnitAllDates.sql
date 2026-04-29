CREATE  
	FUNCTION dbo.FN_GetBusinessUnitAllDates(
		@FutureDate DATE 
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20250507	Mazhar			Initial Version

Returns a list of Month Start and End Dates that cover the active period for each BusinessUnit 
DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
DECLARE	@FutureDate	DATE = DATEADD(MONTH, 19, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

SELECT * FROM dbo.FN_GetBusinessUnitAllDates (@FutureDate);
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	WITH cteBusinessUnitDates
	AS(
		SELECT	B.BusinessUnitBk, 
				B2.BusinessUnitSk AS BusinessUnitSk, 
				MIN(DATEFROMPARTS(YEAR(B._crda_ActiveFromDate), MONTH(B._crda_ActiveFromDate), 1)) AS ActiveFrom , 
				IIF(
						MAX(CAST(B._crda_ActiveToDate AS DATE)) = '90001231',
							@FutureDate ,
								MAX(CAST(B._crda_ActiveToDate AS DATE))
					)						AS ActiveTo 
		FROM	dbo.DimBusinessUnit B 

		LEFT JOIN 
				(
					SELECT	B1.BusinessUnitBk, B1.BusinessUnitSk
					FROM	dbo.DimBusinessUnit B1 
					WHERE	B1.IsCurrent = 1 
				)	B2	ON	B2.BusinessUnitBk = B.BusinessUnitBk 

		WHERE B.BusinessUnitSk > 1
		GROUP BY B.BusinessUnitBk, B2.BusinessUnitSk 
	)
	SELECT	D.[Date]			AS PeriodStart	, 
			D.DateSk			AS PeriodStartSk, 
			EOMONTH(D.[Date])		AS PeriodEnd	, 
			CAST(CONVERT(VARCHAR(8),EOMONTH(D.[Date]), 112) AS INT)	AS PeriodEndSk	, 
			BU.BusinessUnitSk	AS BusinessUnitSk 

	FROM	dbo.DimDate		D

	CROSS APPLY cteBusinessUnitDates BU 

	WHERE	D.DayNumberInMonth = 1 
	AND		D.[Date] >= BU.ActiveFrom AND D.[Date] <= BU.ActiveTo
	AND		D.[Date] <= @FutureDate ;