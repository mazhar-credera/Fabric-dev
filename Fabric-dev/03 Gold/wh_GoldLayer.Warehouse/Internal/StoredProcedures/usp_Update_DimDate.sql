CREATE   
	PROCEDURE Internal.usp_Update_DimDate
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
AS 
BEGIN 
	SET NOCOUNT ON ;
/*
	=========================================================
	*	Creating a date dimension or calendar table in SQL Server
	*	English and Wales
	*	This script will need to be updated for any extra Bank holidays announced by the UK Govt (Royal Weddings, Royal Deaths, Royal Anniversaries etc)
	*
	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DimDate]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DimDate]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DimDate]')
	EXEC Internal.usp_Update_DimDate @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM Internal.DimDate ; 
	TRUNCATE TABLE Internal.DimDate
	=========================================================*/
	--Default Parameters
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			@_Watermark		DATETIME = CONVERT(DATETIME2, @Watermark, 121),
			@_ProcessId		INT = @ProcessId;


	BEGIN TRY 
		DECLARE @StartDate DATE = '20000101', @NumberOfYears INT = 50;
		DECLARE @CutoffDate DATE = DATEADD(YEAR, @NumberOfYears, @StartDate);
		DECLARE @Top INT = DATEDIFF(DAY, @StartDate, @CutoffDate) 

		-- prevent set or regional settings from interfering with 
		-- interpretation of dates / literals
		SET DATEFIRST 7 ;	--SUNDAY is first day of week
		SET DATEFORMAT	DMY ;
		SET LANGUAGE	British ;


		-- this is just a holding table for intermediate calculations:
		DROP TABLE IF EXISTS Internal.tempDimDate;

		CREATE TABLE Internal.tempDimDate 
		(
			[date]			DATE , 
			[day]			INT NULL,
			[month]			INT NULL,
			FirstOfMonth	DATE NULL,
			[MonthName]		VARCHAR(50) NULL , 
			FirstDayOfWeek	DATE NULL , 
			FirstDayOfWorkWeek	DATE NULL , 
			WeekEnding		DATE NULL, 
			[week]			INT NULL,
			[ISOweek]		INT NULL ,
			[DayOfWeek]		INT NULL ,
			[DayOfWorkWeek]	INT NULL ,
			[quarter]		INT NULL,
			[half]			SMALLINT NULL,
			[year]			INT NULL,
			FirstOfYear		DATE NULL,
			Style112		CHAR(8) NULL,
			Style103		CHAR(10) NULL
		);

		INSERT Internal.tempDimDate
			(
				[date] ,
				[day]	,
				[month]	,
				FirstOfMonth,
				[MonthName]	 , 
				FirstDayOfWeek	 , 
				FirstDayOfWorkWeek	 , 
				WeekEnding		, 
				[week]			, 
				[ISOweek]		, 
				[DayOfWeek]		, 
				[DayOfWorkWeek]	, 
				[quarter]		, 
				[year]			,
				FirstOfYear		,
				Style112		,
				Style103		
			) 
		SELECT 
			[date] , 
			CAST(DATEPART(DAY, [date]) AS INT),
			CAST(DATEPART(MONTH, [date]) AS INT),
			CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, [date]), 0) AS DATE),
			CAST(DATENAME(MONTH, [date]) AS VARCHAR(50)),
			CAST(DATEADD(DAY, 1 - DATEPART(WEEKDAY, [date]), [date]) AS DATE) , 
			CAST(DATEADD(DAY, 1, DATEADD(DAY, 1 - DATEPART(WEEKDAY, [date]), [date])) AS DATE) , 
			CAST(DATEADD(DAY, -1 * DATEPART(WEEKDAY, [date]) + 7, [date]) AS DATE), 
			CAST(DATEPART(WEEK, [date]) AS INT),
			CAST(DATEPART(ISO_WEEK, [date]) AS INT) ,
			CAST(DATEPART(WEEKDAY, [date]) AS INT) ,
			CAST(IIF(DATEPART(WEEKDAY, [date]) - 1 = 0, 7, DATEPART(WEEKDAY, [date]) - 1) AS INT) ,
			CAST(DATEPART(QUARTER, [date]) AS INT),
			CAST(DATEPART(YEAR, [date]) AS INT),
			CAST(DATEADD(YEAR, DATEDIFF(YEAR, 0, [date]), 0) AS DATE),
			CAST(CONVERT(CHAR(25), [date], 112) AS CHAR(8)),
			CAST(CONVERT(CHAR(25), [date], 103) AS CHAR(10)) 
		FROM
		(
		  SELECT [date] = DATEADD(DAY, [value] - 1, @StartDate)
		  FROM 
		  (
			SELECT [value]
			FROM GENERATE_SERIES(1, @Top)
		  ) AS x
		) AS y;

		UPDATE Internal.tempDimDate
		SET	[half]				= CONVERT(SMALLINT,CASE [quarter] WHEN 1 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 2 WHEN 4 THEN 2 END)

		TRUNCATE TABLE Internal.DimDate;

		INSERT Internal.DimDate  (
			 [DateKey]
			,[Date]
			,[Day]
			,[DaySuffix]
			,[Weekday]
			,[WeekDayName]
			,[IsWeekend]
			,[IsHoliday]
			,[IsBankHoliday]
			,HolidayText
			,[DOWInMonth]
			,[DayOfYear]
			,[WeekOfMonth]
			,[WeekOfYear]
			,[ISOWeekOfYear]
			,[Month]
			,[MonthName]
			,[Quarter]
			,[QuarterName]
			,[QuarterYear]
			,[Half]
			,[HalfName]
			,[Year]
			,[MMYYYY]
			,[ShortMonthYear]
			,[LongMonthYear]
			,[WeekEnding]

			,FirstDayOfWeek
			,FirstDayOfWorkWeek

			,[FirstDayOfMonth]
			,[LastDayOfMonth]
			,[FirstDayOfQuarter]
			,[LastDayOfQuarter]
			,[FirstDayOfHalf]
			,[LastDayOfHalf]
			,[FirstDayOfYear]
			,[LastDayOfYear]
			,[FirstDayOfNextMonth]
			,[FirstDayOfNextYear]
			,[TaxYear]
			,[TaxQuarter]
			,[FiscalYear]
			,[FiscalQuarter]
			,IsNonWorkDay 
		)
		SELECT 
			DateKey			= CONVERT(INT, Style112),
			[Date]			= [date],
			[Day]			= CONVERT(SMALLINT, [day]),
			DaySuffix		= CONVERT(CHAR(2), CASE WHEN [day] / 10 = 1 THEN 'th' ELSE 
								CASE RIGHT([day], 1) WHEN '1' THEN 'st' WHEN '2' THEN 'nd' 
								WHEN '3' THEN 'rd' ELSE 'th' END END),
			[Weekday]		= CONVERT(SMALLINT, [DayOfWeek]),
			[WeekDayName]	= CONVERT(VARCHAR(10), DATENAME(WEEKDAY, [date])),
			[IsWeekend]		= CONVERT(BIT, CASE WHEN [DayOfWeek] IN (1,7) THEN 1 ELSE 0 END),	--DATEFIRST 7
			[IsHoliday]		= CONVERT(BIT, 0),
			[IsBankHoliday] = CONVERT(BIT, 0),
			HolidayText		= CONVERT(VARCHAR(64), NULL),
			[DOWInMonth]	= CONVERT(SMALLINT, ROW_NUMBER() OVER 
							(PARTITION BY FirstOfMonth, [DayOfWeek] ORDER BY [date])),
			[DayOfYear]		= CONVERT(SMALLINT, DATEPART(DAYOFYEAR, [date])),
			WeekOfMonth		= CONVERT(SMALLINT,	DENSE_RANK() 
												OVER 
												(
													PARTITION BY	[year], [month] 
													ORDER BY		[week]
												)
									),
			WeekOfYear		= CONVERT(SMALLINT, [week]),
			ISOWeekOfYear	= CONVERT(SMALLINT, [ISOweek]),
			[Month]			= CONVERT(SMALLINT, [month]),
			[MonthName]		= CONVERT(VARCHAR(10), [MonthName]),
			[Quarter]		= CONVERT(SMALLINT, [quarter]),
			QuarterName		= CONVERT(VARCHAR(6), CASE [quarter] WHEN 1 THEN 'First' 
								WHEN 2 THEN 'Second' WHEN 3 THEN 'Third' WHEN 4 THEN 'Fourth' END), 
			QuarterYear		= CONVERT(VARCHAR(7), 'Q' + CONVERT(CHAR(1), [quarter]) + ' ' + LEFT(Style112, 4)) ,
			[Half]			= CONVERT(SMALLINT,CASE [quarter] WHEN 1 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 2 WHEN 4 THEN 2 END) ,
			HalfName		= CONVERT(VARCHAR(6),CASE [quarter] WHEN 1 THEN 'First' WHEN 2 THEN 'First' WHEN 3 THEN 'Second' WHEN 4 THEN 'Second' END) ,
			[Year]			= [year],
			MMYYYY			= CONVERT(CHAR(6), REPLACE(RIGHT(Style103, 7), '/', '') ),
			ShortMonthYear	= CONVERT(CHAR(8), LEFT([MonthName], 3) + ' ' + LEFT(Style112, 4)),
			LongMonthYear	= CONVERT(CHAR(20), [MonthName] + ' ' + LEFT(Style112, 4)),
			WeekEnding		= WeekEnding , 

			FirstDayOfWeek		= FirstDayOfWeek ,
			FirstDayOfWorkWeek	= FirstDayOfWorkWeek , 

			FirstDayOfMonth     = FirstOfMonth,
			LastDayOfMonth      = MAX([date]) OVER (PARTITION BY [year], [month]),
			FirstDayOfQuarter   = MIN([date]) OVER (PARTITION BY [year], [quarter]),
			LastDayOfQuarter    = MAX([date]) OVER (PARTITION BY [year], [quarter]),
			FirstDayOfHalf      = MIN([date]) OVER (PARTITION BY [year], [half]),
			LastDayOfHalf       = MAX([date]) OVER (PARTITION BY [year], [half]),
			FirstDayOfYear      = FirstOfYear,
			LastDayOfYear       = MAX([date]) OVER (PARTITION BY [year]),
			FirstDayOfNextMonth = DATEADD(MONTH, 1, FirstOfMonth),
			FirstDayOfNextYear  = DATEADD(YEAR,  1, FirstOfYear) ,
			TaxYear				= '', 
			TaxQuarter			= [quarter] ,
			FiscalYear			= CONVERT(INT,[year]), 
			FiscalQuarter		= [quarter] ,
			IsNonWorkDay		= CONVERT(BIT, 0) 
		FROM Internal.tempDimDate 
		;

/*
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DimDate]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[Internal].[usp_Update_DimDate]')
	EXEC Internal.usp_Update_DimDate @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
*/


		UPDATE	Internal.DimDate
		SET		TaxYear =	CASE 
								WHEN [Month] IN (1, 2, 3) 
									THEN CONVERT(CHAR(4), [Year]-1) +'-'+ RIGHT(MMYYYY,2)
								ELSE 
									CONVERT(CHAR(4), [Year]) + '-'+ RIGHT(CONVERT(CHAR(4), [Year]+1),2) 
							END ; 

		UPDATE	Internal.DimDate
		SET		TaxYear =	IIF([Day] < 6 ,
									CONVERT(CHAR(4), [Year]-1) +'-'+ RIGHT(MMYYYY,2) ,
									TaxYear
								) 
		WHERE	[Month] = 4; 


		/*===========================
		*	IsHoliday Updates
		============================*/
		;WITH x AS 
		(
		  SELECT DateKey, [Date], IsHoliday, HolidayText, FirstDayOfYear, IsBankHoliday, [Year]
			,DOWInMonth, [MonthName], [WeekDayName], [Day],
			LastDOWInMonth = ROW_NUMBER() OVER 
			(
			  PARTITION BY FirstDayOfMonth, [Weekday] 
			  ORDER BY [Date] DESC
			)
			,FirstDOWInMonth = ROW_NUMBER() OVER 
			(
			  PARTITION BY FirstDayOfMonth, [Weekday] 
			  ORDER BY [Date] ASC
			)
		  FROM Internal.DimDate
		) 

		/*=================================
		*	UK Public Holidays
		=================================*/
		UPDATE x 
		SET
			 IsHoliday = 1
			,HolidayText = CASE
							  WHEN ([Date] = FirstDayOfYear) 
								THEN 'New Year''s Day'
							  WHEN ([Day] = 29 AND [MonthName] = 'April' AND [Year] = 2011)
								THEN 'Royal Wedding Bank Holiday'				-- (Royal Wedding)
							  WHEN ([FirstDOWInMonth] = 1 AND [MonthName] = 'May' AND [WeekDayName] = 'Monday')AND [Year] <> 2020
								THEN 'Early May Bank Holiday'					-- (First Monday in May)
							  WHEN ([FirstDOWInMonth] = 2 AND [MonthName] = 'May'   AND [WeekDayName] = 'Friday') AND [Year] = 2020
								THEN 'Early May Bank Holiday'					-- (Early May Bank Holiday (substitute day - 75th VE Day)
							  WHEN ([FirstDOWInMonth] = 2 AND [MonthName] = 'May'   AND [WeekDayName] = 'Monday') AND [Year] = 2023
								THEN 'King Charles III''s Coronation Holiday'	-- (King Charles III's coronation holiday)
							  WHEN ([LastDOWInMonth] = 1 AND [MonthName] = 'May'   AND [WeekDayName] = 'Monday') AND [Year] NOT IN (2012, 2022)
								THEN 'Spring Bank Holiday'						-- (Last Monday in May)
							  WHEN ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Thursday') AND [Year] IN (2022)
								THEN 'Spring Bank Holiday'						-- (First Thursday in June - due to Platinum Jubilee) 
							  WHEN ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Monday') AND [Year] = 2012
								THEN 'Spring Bank Holiday'						-- (Spring bank holiday (substitute day - Queen’s Diamond Jubilee year)
							  WHEN ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Tuesday') AND [Year] = 2012
								THEN 'Queen’s Diamond Jubilee Bank Holiday'		-- (Queen’s Diamond Jubilee (extra bank holiday)
							  WHEN ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Friday') AND [Year] = 2022
								THEN 'Platinum Jubilee Bank Holiday'			-- (Queen’s Platinum Jubilee (extra bank holiday)
							  WHEN ([FirstDOWInMonth] = 3 AND [MonthName] = 'September'   AND [WeekDayName] = 'Monday') AND [Year] = 2022
								THEN 'Bank Holiday for the State Funeral QEII'	-- (Bank Holiday for the State Funeral of Queen Elizabeth II)
							  WHEN ([LastDOWInMonth] = 1 AND [MonthName] = 'August'   AND [WeekDayName] = 'Monday')
								THEN 'Summer Bank Holiday'						-- (Last Monday in August)
							  WHEN ([MonthName] = 'December' AND [Day] = 25)
								THEN 'Christmas Day'
							  WHEN ([MonthName] = 'December' AND [Day] = 26)
								THEN 'Boxing Day'
							  END
		WHERE 
			([Date] = FirstDayOfYear)
			OR ([Day] = 29 AND [MonthName] = 'April' AND [Year] = 2011)
			OR ([FirstDOWInMonth] = 1 AND [MonthName] = 'May' AND [WeekDayName] = 'Monday')AND [Year] <> 2020
			OR ([LastDOWInMonth] = 1 AND [MonthName] = 'May'   AND [WeekDayName] = 'Monday') AND [Year] NOT IN (2012,2022)
			OR ([FirstDOWInMonth] = 2 AND [MonthName] = 'May'   AND [WeekDayName] = 'Friday') AND [Year] = 2020
			OR ([FirstDOWInMonth] = 2 AND [MonthName] = 'May'   AND [WeekDayName] = 'Monday') AND [Year] = 2023
			OR ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Thursday') AND [Year] IN (2022) 
			OR ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Monday') AND [Year] = 2012 
			OR ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Friday') AND [Year] = 2022 
			OR ([FirstDOWInMonth] = 3 AND [MonthName] = 'September'   AND [WeekDayName] = 'Monday') AND [Year] = 2022
			OR ([FirstDOWInMonth] = 1 AND [MonthName] = 'June'   AND [WeekDayName] = 'Tuesday') AND [Year] = 2012
			OR ([LastDOWInMonth] = 1 AND [MonthName] = 'August'	AND [WeekDayName] = 'Monday')
			OR ([MonthName] = 'December' AND [Day] = 25)
			OR ([MonthName] = 'December' AND [Day] = 26);
		

		/*============================
		*	New Years Bank Holiday
		*	Calculate Substitute day
		=============================*/
		;WITH x
		AS(
			SELECT
				[Date], [Day], [Weekday], WeekDayName, IsWeekend, IsHoliday, IsBankHoliday
				,NewYearBankHoliday=
					CASE
						WHEN
							WeekDayName IN ( 'Saturday')
								THEN DATEADD(DAY, 2, [Date])
						WHEN
							WeekDayName IN ( 'Sunday')
								THEN DATEADD(DAY, 1, [Date])
						ELSE
							[Date]
					END
			FROM
				Internal.DimDate
			WHERE
				DayOfYear = 1
		)
		UPDATE
			D
		SET
			 IsHoliday = 1
			,IsBankHoliday = 1
			,HolidayText = 'New Year''s Bank Holiday'
		FROM
			Internal.DimDate	D
		INNER JOIN
			x X	ON X.NewYearBankHoliday = D.Date;
		

		/*===========================
		*	Easter
		*	Calculate Bank Holidays
		============================*/
		;WITH x AS 
		(
			SELECT d.[Date], d.IsHoliday, d.HolidayText, h.HolidayName, IsBankHoliday
			FROM Internal.DimDate AS d
			CROSS APPLY Internal.GetEasterHolidays(d.[Year]) AS h
			WHERE d.[Date] = h.[Date]
		)
		UPDATE
			x
		SET
			 IsHoliday = 1
			,IsBankHoliday = CASE
								WHEN HolidayName IN ( 'Good Friday', 'Easter Monday') 
									THEN 1
								ELSE
									0
							 END
			,HolidayText = HolidayName;
		

		/*=========================
		*	Update IsBankHoliday
		*	for Bank Holidays
		=========================*/
		UPDATE
			Internal.DimDate
		SET
			IsBankHoliday = 1
		WHERE
			HolidayText LIKE '%Bank Holiday';
		

		/*=========================================
		*	Christmas 
		*	Calculate Substitute bank holiday
		==========================================*/
		;WITH X
		AS(
			SELECT
				Date, Day, Weekday, WeekDayName, IsWeekend, IsHoliday, HolidayText, IsBankHoliday
				,CASE
					WHEN
						(WeekDayName IN ( 'Saturday') AND ([MonthName] = 'December' AND [Day] = 25))
							THEN DATEADD(DAY, 2, [Date])
					WHEN
						(WeekDayName IN ( 'Sunday') AND ([MonthName] = 'December' AND [Day] = 25))
							THEN DATEADD(DAY, 1, [Date])
					ELSE
						[Date]
				 END		'XMas_BankHoliday'
			FROM
				Internal.DimDate
			WHERE
				([MonthName] = 'December' AND [Day] = 25)
		)
		UPDATE
			D
		SET
			 IsHoliday = 1
			,IsBankHoliday = 1
			,HolidayText = 'Christmas Day Bank Holiday'
		FROM
			Internal.DimDate	D
		INNER JOIN
			X	ON X.XMas_BankHoliday = D.Date ;
		

		/*=========================================
		*	Boxing Day 
		*	Calculate Substitute bank holiday
		==========================================*/
		;WITH X
		AS(
			SELECT
				Date, Day, Weekday, WeekDayName, IsWeekend, IsHoliday, HolidayText, IsBankHoliday
				,CASE
					WHEN
						(WeekDayName IN ( 'Saturday') AND ([MonthName] = 'December' AND [Day] = 26))
							THEN DATEADD(DAY, 2, [Date])
					WHEN
						(WeekDayName IN ( 'Sunday') AND ([MonthName] = 'December' AND [Day] = 26))
							THEN DATEADD(DAY, 2, [Date])
					WHEN	--to cater for Christmas Day Substitute bank holiday
						(WeekDayName IN ( 'Monday') AND ([MonthName] = 'December' AND [Day] = 26))
							THEN DATEADD(DAY, 1, [Date])
					ELSE
						[Date]
				 END		'BoxDay_BankHoliday'
			FROM
				Internal.DimDate
			WHERE
				([MonthName] = 'December' AND [Day] = 26)
		)
		UPDATE
			D
		SET
			 IsHoliday = 1
			,IsBankHoliday = 1
			,HolidayText = 'Boxing Day Bank Holiday'
		FROM
			Internal.DimDate	D
		INNER JOIN
			X	ON X.BoxDay_BankHoliday = D.Date;
		

		/*=========================
		*	Update IsNonWorkDay
		*	for Bank Holidays
		=========================*/
		UPDATE
			Internal.DimDate
		SET
			IsNonWorkDay = (case when [IsWeekend]=(1) OR [IsBankHoliday]=(1) then (1) else (0) end) ;
		

		/*Future date*/
		INSERT INTO [Internal].[DimDate](
			 [DateKey]
			,[Date]
			,[Day]
			,[DaySuffix]
			,[Weekday]
			,[WeekDayName]
			,[IsWeekend]
			,[IsHoliday]
			,[IsBankHoliday]
			,[DOWInMonth]
			,[DayOfYear]
			,[WeekOfMonth]
			,[WeekOfYear]
			,[ISOWeekOfYear]
			,[Month]
			,[MonthName]
			,[Quarter]
			,[QuarterName]
			,[QuarterYear]
			,[Half]
			,[HalfName]
			,[Year]
			,[MMYYYY]
			,[ShortMonthYear]
			,[LongMonthYear]
			,[TaxYear]
			,[WeekEnding]
			,FirstDayOfWeek
			,FirstDayOfWorkWeek
			,[FirstDayOfMonth]
			,[LastDayOfMonth]
			,[FirstDayOfQuarter]
			,[LastDayOfQuarter]
			,[FirstDayOfHalf]
			,[LastDayOfHalf]
			,[FirstDayOfYear]
			,[LastDayOfYear]
			,[FirstDayOfNextMonth]
			,[FirstDayOfNextYear]
			,[TaxQuarter]
			,[FiscalYear]
			,[FiscalQuarter]
			,IsNonWorkDay 
		)  
		SELECT
			 99991231
			,'99991231'
			, 31
			, 'st'
			, 0
			, 'FutureDay'
			,0
			,1
			,1
			,0
			,365
			,5
			,53
			,52
			,12
			,'December'
			,4
			,'Fourth'
			,'Q4 9999'
			, 2
			, 'Second'
			, 9999
			,'129999'
			, 'Dec 9999'
			,'December 9999'
			, '9999-91'
			, '9999-01-01'
			, '9999-12-28'
			, '9999-12-29'
			, '9999-12-01'
			, '9999-12-31'
			, '9999-10-01'
			, '9999-12-31'
			, '9999-07-01'
			, '9999-12-31'
			, '9999-01-01'
			, '9999-12-31'
			, '9999-01-01'
			, '9999-01-01'
			, 4
			,'9999'
			, 4 
			, 0 
		WHERE NOT EXISTS(
			SELECT	1/0
			FROM	Internal.DimDate
			WHERE	DateKey = 99991231
		) ;
		

		DROP TABLE IF EXISTS Internal.tempDimDate;
		SET LANGUAGE	us_english ;

	END TRY
	
	BEGIN CATCH
		THROW ;
		DROP TABLE IF EXISTS Internal.tempDimDate;
		SELECT IsSuccess=0
	END CATCH;

	SELECT InitialWatermark=NULL, UpdatedWatermark = NULL;

END;