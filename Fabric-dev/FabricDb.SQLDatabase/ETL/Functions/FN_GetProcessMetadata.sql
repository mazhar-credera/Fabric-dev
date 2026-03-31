CREATE  
	FUNCTION ETL.FN_GetProcessMetadata(
		@stagingProjection VARCHAR(512) , @ProcessPath VARCHAR(512)
/*
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_Resource', 'pl_IngestSalesforce')
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_Resource', 'pl_LoadSilverFromBronze')
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_DimDate', '[Internal].[usp_Update_DimDate]')
*/
) RETURNS TABLE
AS RETURN

	SELECT 
		 PM.ProcessId 
		,p.StagingProjection
		,PM.ProcessPath 
		,p.IngestPattern
		,P.PrimaryKeys
		,PrimaryKeysJson				= CONCAT('["',P.PrimaryKeys,'"]')
		,p.DeltaLakeSourceFolder 
		,DeltaLakeBronzeFolder			= p.DeltaLakeSourceFolder
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
		,ObjNames.BronzeTableShortcut
		,BronzeTableShortcutPath		= REPLACE(objNames.BronzeTableShortcut, '.', '/')
		,objNames.BronzeKantataIdTableName
		,fqObjNames.BronzeTableShortcutFqname
		,fqObjNames.BronzeKantataIdTableFqName
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
							pc.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData pc
					WHERE	PC.StagingProjection = p.StagingProjection
				  ) 
		,KantataHashColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							pc.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData pc
					WHERE	PC.StagingProjection =  p.StagingProjection 
					AND		PC.ColumnName NOT IN ('Id','LastModifiedDate','SystemModstamp','LastModifiedDateTime','Last_Modified_DateTime'
													,'CreatedById','LastModifiedById','Last_Modified_Date__c','LastActivityDate','LastViewedDate', 'LengthOfService__c' --Kimble_Resource
														,'_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
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
					FROM ETL.KantataColumnMetaData pc
					WHERE	PC.StagingProjection =  p.StagingProjection 
					AND		PC.ColumnName NOT IN ('Id','LastModifiedDate','SystemModstamp','LastModifiedDateTime','Last_Modified_DateTime'
													,'CreatedById','LastModifiedById','Last_Modified_Date__c','LastActivityDate','LastViewedDate', 'LengthOfService__c' --Kimble_Resource
														,'_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
				  ) 
		,KantataColumnMapping	= 
				CASE SourceFormat
					WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' + (
					SELECT STRING_AGG(
						CAST(
							'{"source":{"name": "' + pc.ColumnName + '"}' 
								+ ',"sink": {"name": "' + pc.[ColumnName] + '"}}'
							AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData pc
					WHERE	PC.StagingProjection =  p.StagingProjection
				  ) + ',{"source":{"name":"_crda_SourceFileName"},"sink":{"name": "_crda_SourceFileName"}}'
					+ ',{"source":{"name":"_crda_SourceExecutionId"},"sink":{"name": "_crda_SourceExecutionId"}}'
					+ ',{"source":{"name":"_crda_SourceExecutionDateTime"},"sink":{"name": "_crda_SourceExecutionDateTime"}}'
					+ ']'
					+ ',"typeConversion": true,"typeConversionSettings":{"allowDataTruncation": false,"treatBooleanAsNumber": false}}' 
				END 
		,SharePointDomain			= IIF(p.TableSchema = 'SharePoint', SP.SharePointDomain , NULL)
		,SharePointSite				= IIF(p.TableSchema = 'SharePoint', SP.SharePointSite  , NULL)
		,SharePointOnlineListName	= IIF(p.TableSchema = 'SharePoint', SP.SharePointOnlineListName , NULL)
	FROM Meta.Process P
	LEFT JOIN ETL.ProcessMap			PM	ON PM.StagingProjection = P.StagingProjection AND PM.ProcessPath = @ProcessPath
	LEFT JOIN ETL.SilverTransformations ST	ON ST.StagingProjection = P.StagingProjection 
	  CROSS APPLY (
		SELECT 
			  BronzeTableName					= P.TableNameRoot
			, BronzeKantataIdTableName			= IIF(p.TableSchema = 'Kantata', 
													CONCAT(TableNameRoot, '_Id') 
													, NULL) 
			, BronzeTableShortcut				= CONCAT('Bronze',p.TableSchema,'.',P.TableNameRoot) 
			, SilverTableName					= CONCAT(p.TableSchema,'.','HISTORY_',P.TableNameRoot) 
			, DeltaLakeSilverFolder				= REPLACE(REPLACE(P.DeltaLakeSourceFolder, P.TableNameRoot, CONCAT('HISTORY_',P.TableNameRoot) ), 'bronze', 'silver')
	  ) objNames
	  CROSS APPLY (
		SELECT 
			  BronzeTableFqName				= CONCAT('lh_BronzeLayer.', p.TableSchema, '.', objNames.BronzeTableName )
			, BronzeKantataIdTableFqName	= IIF(p.TableSchema = 'Kantata', 
													CONCAT('lh_BronzeLayer.',p.TableSchema, '.', objNames.BronzeKantataIdTableName) 
													, NULL) 
			, BronzeTableShortcutFqname		= CONCAT('lh_SilverLayer.','Bronze',p.TableSchema,'.',P.TableNameRoot) 
			, SilverTableFqName				= CONCAT('lh_SilverLayer.', objNames.SilverTableName) 
	  ) fqObjNames 
	  OUTER APPLY (
		SELECT 
			 SharePointDomain		 = MAX(IIF(D.ordinal = 1, D.[value], NULL))
			,SharePointSite			 = MAX(IIF(D.ordinal = 2, D.[value], NULL))
			,SharePointOnlineListName= MAX(IIF(D.ordinal = 3, D.[value], NULL))
		FROM string_split(P.ApiEndPoint, '\', 1) D
	  ) SP  
	WHERE	p.StagingProjection = @stagingProjection 
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
		,KantataHashColumns		= NULL 
		,KantataHashColumnsJson	= NULL 
		,KantataColumnMapping	= NULL 
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

