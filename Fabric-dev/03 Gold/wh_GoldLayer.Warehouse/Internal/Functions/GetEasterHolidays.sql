CREATE --OR ALTER 
	FUNCTION [Internal].GetEasterHolidays(@year INT) 
RETURNS TABLE
WITH SCHEMABINDING
AS 
RETURN 
(
	WITH x AS 
	(
	SELECT [Date] = CONVERT(DATE, RTRIM(@year) + '0' + RTRIM([Month]) 
		+ RIGHT('0' + RTRIM([Day]),2))
		FROM (SELECT [Month], [Day] = DaysToSunday + 28 - (31 * ([Month] / 4))
		FROM (SELECT [Month] = 3 + (DaysToSunday + 40) / 44, DaysToSunday
		FROM (SELECT DaysToSunday = paschal - ((@year + @year / 4 + paschal - 13) % 7)
		FROM (SELECT paschal = epact - (epact / 28)
		FROM (SELECT epact = (24 + 19 * (@year % 19)) % 30) 
		AS epact) AS paschal) AS dts) AS m) AS d
	)
	SELECT [Date], HolidayName = 'Easter Sunday' FROM x
	UNION ALL SELECT DATEADD(DAY,-2,[Date]), 'Good Friday'   FROM x
	UNION ALL SELECT DATEADD(DAY, 1,[Date]), 'Easter Monday' FROM x
);