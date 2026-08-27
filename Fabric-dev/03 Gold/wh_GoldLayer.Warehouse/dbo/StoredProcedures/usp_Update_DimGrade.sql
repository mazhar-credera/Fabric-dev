CREATE   
	PROCEDURE dbo.usp_Update_DimGrade
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimGrade]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimGrade]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimGrade]')
	EXEC dbo.usp_Update_DimGrade @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM dbo.DimGrade ORDER BY GradeSk;
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters 
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 

	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			TRUNCATE TABLE dbo.DimGrade ; 

			INSERT INTO dbo.DimGrade ( 
				GradeSk, GradeBk, [Name] , 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT 
				GradeSk, GradeBk, [Name] , 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
						-1 , 'UnknownRecord' , 'UnknownRecord' , 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	
								GradeSk, GradeBk, [Name] , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimGrade B 
				WHERE	B.GradeSk = T.GradeSk 
			) ; 


			SELECT	GradeBk				= T.Id , 
					[Name]				= ISNULL(T.[Name] , '') , 
					T.CurrencyIsoCode , 
					GradeShortName		= T.Shortname__c ,
					GradeSortOrder		= T.SortOrder__c ,
					IsFeeEarning		= ISNULL(T.FeeEarning__c,0) , 
					GradeSortConcat		= T.GradeSortConcat__c , 
					NAVRevenueDimension = T.NAVRevenueDimension__c , 

					GradeGroupBk		= T.DMW_GradeGroup__c ,
					GradeGroupName		= K.[Name] , 
					GradeGroupShortName	= K.Shortname__c , 
					GradeGroupSortName	= K.SortName__c ,
					GroupofGroups		= K.GroupofGroups__c ,

					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_Grade	T 
			LEFT JOIN	lh_SilverLayer.Kantata.HISTORY_GradeGroup	K	ON	K.Id = T.DMW_GradeGroup__c
														AND	K._crda_ActiveToDateTime = '9999-12-31 23:59:59'  
														AND	K._crda_isDeleted = 0

			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  ISNULL(T.[Name] , '')	
							, T.CurrencyIsoCode	
							, T.Shortname__c
							, T.SortOrder__c	 
							, ISNULL(T.FeeEarning__c,0)
							, T.GradeSortConcat__c	
							, T.NAVRevenueDimension__c	

							, T.DMW_GradeGroup__c		
							, K.[Name]	
							, K.Shortname__c 	
							, K.SortName__c		
							, K.GroupofGroups__c
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			AND		T._crda_isDeleted = 0 ; 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Grade';

			INSERT INTO dbo.DimGrade(
				GradeSk , 
				GradeBk , 
				[Name] , 
				CurrencyIsoCode , 
				GradeShortName	, 
				GradeSortOrder ,
				IsFeeEarning , 
				GradeSortConcat , 
				NAVRevenueDimension , 

				GradeGroupBk , 
				GradeGroupName , 
				GradeGroupShortName , 
				GradeGroupSortName , 
				GroupofGroups 

				,_crda_ActiveFromDate 
				,_crda_ActiveToDate 
				,_crda_ActiveFromDateSk 
				,_crda_ActiveToDateSk 
				,IsCurrent 
				,_crda_Hash 
				,_crda_CreatedExecutionId  
				,_crda_CreatedDateTime 
				,_crda_isDeleted
			)
			SELECT 
				ROW_NUMBER()OVER (ORDER BY SRC.GradeBk, SRC._crda_ActiveFromDateTime) , 
				SRC.GradeBk , 
				SRC.[Name] , 
				SRC.CurrencyIsoCode , 
				SRC.GradeShortName	, 
				SRC.GradeSortOrder ,
				SRC.IsFeeEarning , 
				SRC.GradeSortConcat , 
				SRC.NAVRevenueDimension , 

				SRC.GradeGroupBk , 
				SRC.GradeGroupName , 
				SRC.GradeGroupShortName , 
				SRC.GradeGroupSortName , 
				SRC.GroupofGroups 

				,SRC._crda_ActiveFromDateTime 
				,SRC._crda_ActiveToDateTime 
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveFromDateTime,(112))))
				,(CONVERT([int],CONVERT([varchar](8),_crda_ActiveToDateTime,(112)))) 
				,IIF( _crda_ActiveToDateTime='9999-12-31 23:59:59', 1, 0 ) 
				,SRC._crda_Hash 
				,@_ExecutionId 
				,GETUTCDATE() 
				,0
			FROM		#Source	SRC 


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Source S ;

			SELECT	InitialWatermark	= @strOldWatermark, 
					UpdatedWatermark	= @strNewWatermark ; 

		COMMIT;

	END TRY
	BEGIN CATCH
		ROLLBACK;
		THROW;
	END CATCH ; 

	IF @@TRANCOUNT > 0 ROLLBACK; 

END;