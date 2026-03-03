CREATE  
	FUNCTION ETL.FN_GetProcessMetadata(
		@stagingProjection VARCHAR(512) 
/*
SELECT * FROM ETL.FN_GetProcessMetadata('SharePoint_DeskReservations')
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_BusinessUnit')
*/
) RETURNS TABLE
AS RETURN

	SELECT
		 PM.ProcessId 
		,p.StagingProjection
		,p.IngestPattern
		,P.PrimaryKeys
		,PrimaryKeysJson				= CONCAT('["',P.PrimaryKeys,'"]')
		,p.DeltaLakeSourceFolder 
		,DeltaLakeBronzeFolder			= p.DeltaLakeSourceFolder
		,objNames.DeltaLakeSilverFolder	
		,P.ApiEndPoint
		,P.SourceFormat
		,P.TableSchema
		,PM.BronzeWatermarkValue 
		,PM.SilverWatermarkValue 
		,P.WatermarkColumnName 
		,P.BronzeDataLoadWatermarkColumn 
		,P.ModificationTimeStampExpression 
		,objNames.BronzeTableName
		,BronzeTablePath				= CONCAT(P.TableSchema,'/',objNames.BronzeTableName)
		,ObjNames.BronzeTableShortcut
		,objNames.BronzeKantataIdTableName
		,fqObjNames.BronzeTableShortcutFqname
		,fqObjNames.BronzeKantataIdTableFqName
		,objNames.SilverTableName
		,SilverTablePath				= CONCAT(P.TableSchema,'/',objNames.SilverTableName)
		,fqObjNames.SilverTableFqName
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
	LEFT JOIN ETL.ProcessMap PM ON PM.StagingProjection = P.StagingProjection AND PM.GroupId = 1 
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
			, SilverTableFqName				= CONCAT('lh_SilverLayer.', p.TableSchema, '.', objNames.SilverTableName) 
	  ) fqObjNames 
	  OUTER APPLY (
		SELECT 
			 SharePointDomain		 = MAX(IIF(D.ItemNumber = 1, D.Item, NULL))
			,SharePointSite			 = MAX(IIF(D.ItemNumber = 2, D.Item, NULL))
			,SharePointOnlineListName= MAX(IIF(D.ItemNumber = 3, D.Item, NULL))
		FROM Internal.DelimitedSplit8K(P.ApiEndPoint, '\') D
	  ) SP  
	WHERE p.StagingProjection LIKE @stagingProjection ;

GO

