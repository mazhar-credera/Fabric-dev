CREATE  
	PROCEDURE dbo.usp_Update_DimSector
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	USAGE
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSector]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSector]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimSector]')
	EXEC dbo.usp_Update_DimSector @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;

	SELECT * FROM [dbo].[DimSector] ORDER BY SectorBk; 
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

			TRUNCATE TABLE dbo.DimSector ; 

			INSERT INTO [dbo].DimSector ( 
				SectorSk, SectorBk, [Name], CurrencyIsoCode, StartDate, EndDate, 
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			SELECT SectorSk, SectorBk, [Name], CurrencyIsoCode, StartDate, EndDate,
					_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
						,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			FROM	(VALUES	(	
					-1 , 'UnknownRecord', 'UnknownRecord', 'ZZZ', '20000101', '20000101', 
							'20000101', '9999-12-31 23:59:59', 20000101, 99991231, 1
								,0x00 , @_ExecutionId, GETUTCDATE(), 0  ) 
					)	AS T(	SectorSk, SectorBk, [Name], CurrencyIsoCode, StartDate, EndDate , 
									_crda_ActiveFromDate, _crda_ActiveToDate, _crda_ActiveFromDateSk, _crda_ActiveToDateSk, IsCurrent 
										,_crda_Hash,_crda_CreatedExecutionId, _crda_CreatedDateTime, _crda_isDeleted 
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimSector B 
				WHERE	B.SectorSk = T.SectorSk 
			) ; 

			SELECT	SectorBk= T.Id , 
					T.[Name], 
					T.CurrencyIsoCode , 
					StartDate	= T.StartDate__c , 
					EndDate		= ISNULL(T.EndDate__c , '99991231') , 
					_crda_ActiveFromDateTime= CONVERT(DATETIME2(6), T._crda_ActiveFromDateTime) , 
					_crda_ActiveToDateTime	= CONVERT(DATETIME2(6), T._crda_ActiveToDateTime), 
					AD._crda_Hash 
			INTO #Source 
			FROM	lh_SilverLayer.Kantata.HISTORY_Sector	T 
			CROSS APPLY (
				SELECT
				CAST(HASHBYTES('MD5',
					CONCAT_WS('||',	
							  T.[Name]		
							, T.CurrencyIsoCode	
							, CONVERT(VARCHAR(35), T.StartDate__c, 121)
							, CONVERT(VARCHAR(35), T.EndDate__c	, 121)
						) 
					) AS VARBINARY(16)) AS _crda_Hash
				)  AD 
			WHERE	T._crda_ActiveFromDateTime > @_Watermark  
			--AND		T._crda_isDeleted = 0 
			AND		T.[Name] NOT IN ('Test'); 

			/*Realign History dates*/ 
			EXEC dbo.usp_CompressHistoriesAndRealignDimensionHistoryDates  @TableNameRoot = 'Sector';


			INSERT INTO dbo.DimSector
			(
				SectorSk , 
				SectorBk , 
				[Name] , 
				CurrencyIsoCode , 
				EndDate , 
				StartDate ,
				SectorGroups 

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
				ROW_NUMBER()OVER (ORDER BY SRC.SectorBk, SRC._crda_ActiveFromDateTime) , 
				SRC.SectorBk , 
				SRC.[Name] , 
				SRC.CurrencyIsoCode , 
				SRC.EndDate , 
				SRC.StartDate , 
				case when [Name]='Public Sector' then 'PS' when [Name]='Insurance' OR [Name]='Financial Services' then 'FSI' when [Name]='Oil, Gas & Utilities' OR [Name]='Commercial' then 'E&C' when [Name]='Portfolio' then 'PF' else 'Not Specified' end 

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
			ORDER BY SRC.SectorBk, SRC._crda_ActiveFromDateTime ; 

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