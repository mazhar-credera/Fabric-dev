CREATE --OR ALTER
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

	SELECT	PeriodStart		= [Date] , 
			PeriodStartSk	= DateSk , 
			PeriodEnd		= EOMONTH([Date]) , 
			PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT) , 
			BU.BusinessUnitSk 
	FROM	dbo.DimDate 
	CROSS APPLY ( 
		SELECT	B.BusinessUnitBk, BusinessUnitSk = B2.BusinessUnitSk , 
				ActiveFrom	= MIN(DATEFROMPARTS(YEAR(B._crda_ActiveFromDate), MONTH(B._crda_ActiveFromDate), 1)) ,
				ActiveTo	= IIF(
									MAX(CAST(B._crda_ActiveToDate AS DATE)) = '90001231',
									@FutureDate ,
									MAX(CAST(B._crda_ActiveToDate AS DATE))
								)
		FROM	dbo.DimBusinessUnit B 
		LEFT JOIN (
			SELECT	B1.BusinessUnitBk, B1.BusinessUnitSk
			FROM	dbo.DimBusinessUnit B1 
			WHERE	B1.IsCurrent = 1 
		)	B2	ON	B2.BusinessUnitBk = B.BusinessUnitBk 
		WHERE B.BusinessUnitSk > 1
		GROUP BY 
			B.BusinessUnitBk, B2.BusinessUnitSk 
	)	BU 
	WHERE	DayNumberInMonth = 1 
	AND		[Date] >= BU.ActiveFrom AND [Date] <= BU.ActiveTo
	AND		[Date] <= @FutureDate ;