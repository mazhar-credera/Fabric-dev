CREATE  
	FUNCTION Internal.FN_ExtractKantataIdFromHtml(
		@Html VARCHAR(1024) = '' 
/*	==============================================================
Date		Name			Change Description
------------------------------------------
20250502	Mazhar			Initial Version

The ActivityAssignmentDemand table in Kantata contains
HTML in two columns where you would expect to find a related Id.
This function attempts to parse the HTML in the format that it is
in and extract the Id from it.

SELECT * FROM Internal.FN_ExtractKantataIdFromHtml ('<a href="/?sort=Strategic Design Services: Lot 1 - WP2 (DG002295)" target="_self"> </a><a href="/a0c3z00000Xve9n" target="_self">Strategic Design Services: Lot 1 - WP2 (DG002295)</a>');
SELECT * FROM Internal.FN_ExtractKantataIdFromHtml ('<a href="/?sort=" target="_self"> </a><a href="/" target="_self"> </a>');
SELECT * FROM Internal.FN_ExtractKantataIdFromHtml ('<a href="/?sort=UK" target="_self"> </a><a href="/a2KD0000000Pok4" target="_self">UK</a>');
================================================================	*/

) RETURNS TABLE
WITH SCHEMABINDING 
AS
RETURN 

	SELECT 
		ShortId 
	FROM (SELECT Html = @Html ) T
	CROSS APPLY (SELECT CHARINDEX('href="/', T.Html, LEN(T.Html)/2) + 7 AS StartPos) AS P1
	CROSS APPLY (SELECT CHARINDEX('"', T.Html, StartPos) AS EndPos) AS P2
	CROSS APPLY (SELECT SUBSTRING(T.Html, StartPos, EndPos - StartPos) AS ShortId) AS Result;