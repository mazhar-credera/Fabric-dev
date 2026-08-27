CREATE --OR ALTER
	FUNCTION dbo.FN_GetSectorAllDates(
		@FutureDate DATE 
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20250507	Mazhar			Initial Version

Returns a list of Month Start and End Dates that cover the active period for each Sector 
DECLARE @TimeNow		DATETIME2= GETUTCDATE() ;
DECLARE	@FutureDate	DATE = DATEADD(MONTH, 19, DATEFROMPARTS(YEAR(@TimeNow), MONTH(@TimeNow), 1)); 

SELECT * FROM dbo.FN_GetSectorAllDates (@FutureDate);
================================================================	*/

) RETURNS TABLE
AS
RETURN 

	SELECT	PeriodStart		= [Date] , 
			PeriodStartSk	= DateSk , 
			PeriodEnd		= EOMONTH([Date]) , 
			PeriodEndSk		= CAST(CONVERT(VARCHAR(8),EOMONTH([Date]), 112) AS INT) , 
			BU.SectorSk 
	FROM	dbo.DimDate 
	CROSS APPLY ( 
		SELECT	B.SectorBk, SectorSk = B2.SectorSk , 
				ActiveFrom	= MIN(DATEFROMPARTS(YEAR(B._crda_ActiveFromDate), MONTH(B._crda_ActiveFromDate), 1)) ,
				ActiveTo	= IIF(
									MAX(CAST(B._crda_ActiveToDate AS DATE)) = '90001231',
									@FutureDate ,
									MAX(CAST(B._crda_ActiveToDate AS DATE))
								)
		FROM	dbo.DimSector B 
		LEFT JOIN (
			SELECT	B1.SectorBk, B1.SectorSk
			FROM	dbo.DimSector B1 
			WHERE	B1.IsCurrent = 1 
		)	B2	ON	B2.SectorBk = B.SectorBk 
		WHERE B.SectorSk > 1
		GROUP BY 
			B.SectorBk, B2.SectorSk 
	)	BU 
	WHERE	DayNumberInMonth = 1 
	AND		[Date] >= BU.ActiveFrom AND [Date] <= BU.ActiveTo
	AND		[Date] <= @FutureDate ;