CREATE   
	PROCEDURE dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates 
		@TableNameRoot	NVARCHAR(255) = N'Account'
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	Kantata (Kimble) Source Dimensions only

	EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates @TableNameRoot = N'Resource'
	EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates @TableNameRoot = N'KimbleUser'
	EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates @TableNameRoot = N'ExchangeRate'
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
WITH RECOMPILE 
AS
BEGIN
SET NOCOUNT ON ;
	
	DECLARE @sql			NVARCHAR(MAX)= N'';
	DECLARE @_DimensionTable NVARCHAR(255) = IIF(@TableNameRoot = N'ExchangeRate', N'Currency', @TableNameRoot) ;
	DECLARE @_BusKeyCol		VARCHAR(255) = @_DimensionTable ;

	/*
	 *	compress histories
	 *	remove zero-change records 
	 *	(changes identified by an updated snapshot may not be changes for us because we only use a subset of attributes)
	*/
	SELECT @sql = 
	CONCAT(
		N'WITH cte AS (
		  SELECT 
			*
		  , LAG(_crda_Hash) 
			OVER(
					PARTITION BY	d.', @_BusKeyCol, N'Bk 
					ORDER BY		d._crda_ActiveFromDateTime 
				) AS PriorDigest 
		  FROM #Source d 
		) 
		DELETE 
		FROM	cte 
		WHERE	_crda_Hash = PriorDigest  /*remove a record when its the same as the previous one*/ 

		/*SELECT PriorDigest = @@ROWCOUNT;*/
	');
	--PRINT @sql;
	EXEC sp_executesql	@stmt = @sql ; 


	/*
	 *	Manually enforce Unique constraint 
	*/
	SET @sql = 
	CONCAT(
		N'WITH cte AS (
		  SELECT 
			*
		  , ROW_NUMBER()  
			OVER(
					PARTITION BY	d.', @_BusKeyCol, N'Bk 
					ORDER BY		d._crda_ActiveFromDateTime 
				) AS RN  
		  FROM #Source d 
		) 
		DELETE 
		FROM	cte 
		WHERE	RN > 1 ;

		/*SELECT EnforceUC = @@ROWCOUNT;*/
	');
	--PRINT @sql;
	EXEC sp_executesql	@stmt = @sql ; 


	/*
	 *	realign history dates 
	*/
	SET @sql='';
	SELECT @sql = 
	CONCAT(
		N'WITH cte 
		AS (
				SELECT 
				d.*
				,CAST(d._crda_ActiveFromDateTime AS DATETIME) AS StartDateTime
				,LEAD(d._crda_ActiveFromDateTime)
					OVER (
						PARTITION BY d.', @_BusKeyCol, N'Bk
						ORDER BY d._crda_ActiveFromDateTime
						) AS NextStart
				, LEAD(DATEADD(MILLISECOND, -3, CAST(d._crda_ActiveFromDateTime AS DATETIME)), 1, ',CHAR(39), N'9999-12-31 23:59:59', CHAR(39), N') 
					OVER (
						PARTITION BY d.', @_BusKeyCol, N'Bk
						ORDER BY d._crda_ActiveFromDateTime
						) AS EndDateTime
				FROM #Source d
		)
		UPDATE cte
		SET _crda_ActiveFromDateTime = StartDateTime
			, _crda_ActiveToDateTime = EndDateTime; 

		/*SELECT RealignDates = @@ROWCOUNT;*/
	');
	--PRINT @sql;
	EXEC sp_executesql	@stmt = @sql ; 


	/*
	 *	Enforce/Check SCD2 Functionality 
	*/
	SET @sql='';
	SELECT @sql = 
	CONCAT(
		N'IF EXISTS
		(
			SELECT *
			FROM
			(
				SELECT	 t.', @_BusKeyCol, N'Bk
						,t._crda_ActiveFromDate
						,PrevValidTo =
							LAG(t._crda_ActiveToDate) 
								OVER	(	PARTITION BY	t.', @_BusKeyCol, N'Bk
											ORDER BY		t._crda_ActiveFromDate
										) 
				FROM dbo.Dim', @_DimensionTable, N' t
			) AS t1
			WHERE 
				t1.PrevValidTo >= t1._crda_ActiveFromDate
		)
		BEGIN
			RAISERROR(',CHAR(39),'SCD2 enforcement faied in [dbo].Dim', @_DimensionTable,CHAR(39),', 11, 1); 
		END ;
	');
	--PRINT @sql;
	EXEC sp_executesql	@stmt = @sql ; 
	
END ;