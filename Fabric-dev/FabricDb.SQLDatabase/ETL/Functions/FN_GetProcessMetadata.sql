CREATE   
	FUNCTION ETL.FN_GetProcessMetadata(
		@stagingProjection VARCHAR(512) , @ProcessPath VARCHAR(512)
/*
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_Resource', 'pl_IngestSalesforce')
SELECT * FROM ETL.FN_GetProcessMetadata('BC_BrightGen_bankAccountLedgerEntries', 'pl_IngestBc365')
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_Resource', 'pl_LoadSilverFromBronze')
SELECT * FROM ETL.FN_GetProcessMetadata('Internal_DimDate', '[Internal].[usp_Update_DimDate]')
*/
) RETURNS TABLE
AS RETURN

	SELECT 
		 PM.ProcessId 
		,P.StagingProjection
		,PM.ProcessPath 
		,P.IngestPattern
		,P.PrimaryKeys
		,PrimaryKeysJson				= CONCAT('["',P.PrimaryKeys,'"]')
		,P.DeltaLakeSourceFolder 
		,DeltaLakeBronzeFolder			= P.DeltaLakeSourceFolder
		,objNames.DeltaLakeSilverFolder	
		,P.ApiEndPoint
		,P.SourceFormat
		,P.TableSchema
		,PM.CurrentWatermark 
		/*Bronze*/
		,P.WatermarkColumnName
		,PM.BronzeWatermarkValue 
		,P.BronzeDataLoadWatermarkColumn
		,objNames.BronzeTableName
		,BronzeTablePath				= CONCAT(P.TableSchema,'/',objNames.BronzeTableName)
		,objNames.BronzeTableShortcut
		,BronzeTableShortcutPath		= REPLACE(objNames.BronzeTableShortcut, '.', '/')
		/*Kantata*/
		,objNames.BronzeKantataIdTableName
		,fqObjNames.BronzeTableShortcutFqname
		,fqObjNames.BronzeKantataIdTableFqName
		/*Bc365*/
		,objNames.BronzeBc365IdTableName
		,fqObjNames.BronzeBc365IdTableFqName

		/*Bronze*/
		/*Silver*/
		,objNames.SilverTableName
		,PM.SilverWatermarkValue 
		,SilverTablePath				= REPLACE(objNames.SilverTableName, '.', '/')
		,fqObjNames.SilverTableFqName
		/*Silver*/
		,P.ModificationTimeStampExpression 
		,TransformationsJson			= ISNULL(ST.TransformationsJson , '{}') 
		,KantataSelectColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							PC.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData PC
					WHERE	PC.StagingProjection = P.StagingProjection
				  ) 
		,Bc365SelectColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							PC.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.Bc365ColumnMetadata PC
					WHERE	P.StagingProjection LIKE '%' +PC.ApiEntitySetName 
				  ) 

		,KantataHashColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							PC.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData PC
					WHERE	PC.StagingProjection =  P.StagingProjection 
					AND		PC.ColumnName NOT IN ('Id','LastModifiedDate','SystemModstamp','LastModifiedDateTime','Last_Modified_DateTime'
													,'CreatedById','LastModifiedById','Last_Modified_Date__c','LastActivityDate','LastViewedDate', 'LengthOfService__c' --Kimble_Resource
														,'_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
				  ) 
		,Bc365HashColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							PC.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.Bc365ColumnMetadata PC
					WHERE	P.StagingProjection LIKE '%' +PC.ApiEntitySetName 
					AND		PC.ColumnName NOT IN ('id','lastModifiedDateTime','_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
				  ) 

		,KantataHashColumnsJson	= 
				'' + (
					SELECT JSON_QUERY(
								'[' +
								STRING_AGG(
									'"' + REPLACE(CAST(ColumnName AS NVARCHAR(MAX)), '"', '\"') + '"',
									','
								) +
								']'
							)
					FROM ETL.KantataColumnMetaData PC
					WHERE	PC.StagingProjection =  P.StagingProjection 
					AND		PC.ColumnName NOT IN ('Id','LastModifiedDate','SystemModstamp','LastModifiedDateTime','Last_Modified_DateTime'
													,'CreatedById','LastModifiedById','Last_Modified_Date__c','LastActivityDate','LastViewedDate', 'LengthOfService__c' --Kimble_Resource
														,'_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
				  ) 
		,Bc365HashColumnsJson	= 
				'' + (
					SELECT JSON_QUERY(
								'[' +
								STRING_AGG(
									'"' + REPLACE(CAST(ColumnName AS NVARCHAR(MAX)), '"', '\"') + '"',
									','
								) +
								']'
							)
					FROM ETL.Bc365ColumnMetadata PC
					WHERE	P.StagingProjection LIKE '%' +PC.ApiEntitySetName 
					AND		PC.ColumnName NOT IN ('id','lastModifiedDateTime','_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
				  ) 
		,KantataColumnMapping	= 
				CASE SourceFormat
					WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' + (
					SELECT STRING_AGG(
						CAST(
							'{"source":{"name": "' + PC.ColumnName + '"}' 
								+ ',"sink": {"name": "' + PC.[ColumnName] + '"}}'
							AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData PC
					WHERE	PC.StagingProjection =  P.StagingProjection
				  ) + ',{"source":{"name":"_crda_SourceFileName"},"sink":{"name": "_crda_SourceFileName"}}'
					+ ',{"source":{"name":"_crda_SourceExecutionId"},"sink":{"name": "_crda_SourceExecutionId"}}'
					+ ',{"source":{"name":"_crda_SourceExecutionDateTime"},"sink":{"name": "_crda_SourceExecutionDateTime"}}'
					+ ']'
					+ ',"typeConversion": true,"typeConversionSettings":{"allowDataTruncation": false,"treatBooleanAsNumber": false}}' 
				END 
		,Bc365ColumnMapping	= 
				CASE SourceFormat
					WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' + (
					SELECT STRING_AGG(
						CAST(
							'{"source":{"name": "' + PC.ColumnName + '"}' 
								+ ',"sink": {"name": "' + PC.[ColumnName] + '"}}'
							AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.Bc365ColumnMetadata PC
					WHERE	P.StagingProjection LIKE '%' +PC.ApiEntitySetName 
				  ) + ',{"source":{"name":"_crda_SourceFileName"},"sink":{"name": "_crda_SourceFileName"}}'
					+ ',{"source":{"name":"_crda_SourceExecutionId"},"sink":{"name": "_crda_SourceExecutionId"}}'
					+ ',{"source":{"name":"BC_CompanyName"},"sink":{"name": "BC_CompanyName"}}'
					+ ',{"source":{"name":"_crda_SourceExecutionDateTime"},"sink":{"name": "_crda_SourceExecutionDateTime"}}'
					+ ']'
					+ COALESCE(',"collectionReference":"$[''' 
					  + REPLACE(REPLACE(NULLIF(p.SourceCollectionReference, ''), '.', ''']['''), '[0]'']', '''][0]') + ''']"', '')
					+ ',"mapComplexValuesToString":true}' 
				END 


		,SharePointDomain			= IIF(P.TableSchema = 'SharePoint', SP.SharePointDomain , NULL)
		,SharePointSite				= IIF(P.TableSchema = 'SharePoint', SP.SharePointSite  , NULL)
		,SharePointOnlineListName	= IIF(P.TableSchema = 'SharePoint', SP.SharePointOnlineListName , NULL)
	FROM Meta.Process P
	LEFT JOIN ETL.ProcessMap			PM	ON PM.StagingProjection = P.StagingProjection AND PM.ProcessPath = @ProcessPath
	LEFT JOIN ETL.SilverTransformations ST	ON ST.StagingProjection = P.StagingProjection 
	  CROSS APPLY (
		SELECT 
			  BronzeTableName				= P.TableNameRoot
			, BronzeKantataIdTableName		= IIF(P.TableSchema = 'Kantata', 
												CONCAT(TableNameRoot, '_Id') 
												, NULL) 
			, BronzeBc365IdTableName		= IIF(P.TableSchema = 'BC', 
												CONCAT(TableNameRoot, '_Id') 
												, NULL) 
			, BronzeTableShortcut			= CONCAT('Bronze',P.TableSchema,'.',P.TableNameRoot) 
			, SilverTableName				= CONCAT(P.TableSchema,'.','HISTORY_',P.TableNameRoot) 
			, DeltaLakeSilverFolder			= REPLACE(REPLACE(P.DeltaLakeSourceFolder, P.TableNameRoot, CONCAT('HISTORY_',P.TableNameRoot) ), 'bronze', 'silver')
	  ) objNames
	  CROSS APPLY (
		SELECT 
			  BronzeTableFqName				= CONCAT('lh_BronzeLayer.', P.TableSchema, '.', objNames.BronzeTableName )
			, BronzeKantataIdTableFqName	= IIF(P.TableSchema = 'Kantata', 
													CONCAT('lh_BronzeLayer.',P.TableSchema, '.', objNames.BronzeKantataIdTableName) 
													, NULL) 
			, BronzeBc365IdTableFqName	= IIF(P.TableSchema = 'BC', 
													CONCAT('lh_BronzeLayer.',P.TableSchema, '.', objNames.BronzeBc365IdTableName) 
													, NULL) 
			, BronzeTableShortcutFqname		= CONCAT('lh_SilverLayer.','Bronze',P.TableSchema,'.',P.TableNameRoot) 
			, SilverTableFqName				= CONCAT('lh_SilverLayer.', objNames.SilverTableName) 
	  ) fqObjNames 
	  OUTER APPLY (
		SELECT 
			 SharePointDomain				= MAX(IIF(D.ordinal = 1, D.[value], NULL))
			,SharePointSite					= MAX(IIF(D.ordinal = 2, D.[value], NULL))
			,SharePointOnlineListName		= MAX(IIF(D.ordinal = 3, D.[value], NULL))
		FROM string_split(P.ApiEndPoint, '\', 1) D
	  ) SP  
	WHERE	P.StagingProjection = @stagingProjection 
	AND		P.IsActive = 1
	UNION ALL
	SELECT 
		 PM.ProcessId 
		,PM.StagingProjection
		,PM.ProcessPath 
		,IngestPattern					= NULL 
		,PrimaryKeys					= NULL 
		,PrimaryKeysJson				= NULL 
		,DeltaLakeSourceFolder			= NULL 
		,DeltaLakeBronzeFolder			= NULL 
		,DeltaLakeSilverFolder			= NULL 
		,ApiEndPoint					= NULL 
		,SourceFormat					= NULL 
		,TableSchema					= NULL 
		,PM.CurrentWatermark 
		/*Bronze*/
		,WatermarkColumnName			= NULL 
		,PM.BronzeWatermarkValue 
		,BronzeDataLoadWatermarkColumn	= NULL 
		,BronzeTableName				= NULL 
		,BronzeTablePath				= NULL
		,BronzeTableShortcut			= NULL 
		,BronzeTableShortcutPath		= NULL
		,BronzeKantataIdTableName		= NULL 
		,BronzeTableShortcutFqname		= NULL 
		,BronzeKantataIdTableFqName		= NULL 
		,BronzeBc365IdTableName			= NULL 
		,BronzeBc365IdTableFqName		= NULL 

		/*Bronze*/
		/*Silver*/
		,SilverTableName				= NULL 
		,PM.SilverWatermarkValue 
		,SilverTablePath				= NULL 
		,SilverTableFqName				= NULL 
		/*Silver*/
		,ModificationTimeStampExpression = NULL 
		,TransformationsJson	= NULL 

		,KantataSelectColumns	= NULL 
		,Bc365SelectColumns		= NULL 

		,KantataHashColumns		= NULL 
		,Bc365HashColumns		= NULL 

		,KantataHashColumnsJson	= NULL 
		,Bc365HashColumnsJson	= NULL 

		,KantataColumnMapping	= NULL 
		,Bc365ColumnMapping	= NULL 

		,SharePointDomain		= NULL 
		,SharePointSite			= NULL 
		,SharePointOnlineListName	= NULL 
	FROM ETL.ProcessMap			PM
	--CROSS APPLY Meta.Process	P	
	WHERE	PM.StagingProjection = @stagingProjection 
	AND		PM.ProcessPath	= @ProcessPath 
	AND		PM.ProcessType	= 'ASQL'
	AND		PM.IsActive		= 1 ;

GO

