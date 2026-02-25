CREATE  
	FUNCTION Meta.FN_GetProcessMetadata(
		@stagingProjection VARCHAR(512) 
/*
SELECT * FROM Meta.FN_GetProcessMetadata('SharePoint_DeskReservations')
SELECT * FROM Meta.FN_GetProcessMetadata('Kantata_BusinessUnit')
*/
) RETURNS TABLE
AS RETURN

	SELECT
		 PM.ProcessId 
		,p.StagingProjection
		,p.IngestPattern
		,p.DeltaLakeSourceFolder 
		,DeltaLakeBronzeFolder			= p.DeltaLakeSourceFolder
		,DeltaLakeSilverFolder			= REPLACE(p.DeltaLakeSourceFolder , 'bronze/', 'silver/')
		,P.ApiEndPoint
		,p.SourceFormat
		,p.TableSchema 
		,objNames.BronzeTableName
		,BronzeTablePath				= CONCAT(P.TableSchema,'/',objNames.BronzeTableName)
		,fqObjNames.BronzeTableFqName
		,objNames.BronzeKantataIdTableName
		,fqObjNames.BronzeKantataIdTableFqName
		,P.WatermarkColumnName
		,P.PrimaryKeys
		,objNames.SilverTableName
		,fqObjNames.SilverTableFqName
		,p.ModificationTimeStampExpression
		,KantataSelectColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							pc.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData pc
					WHERE	CONCAT('Kantata_', REPLACE(REPLACE(REPLACE(PC.TableApiName, 'KimbleOne__', ''), '__c', ''), '_', '')) = p.StagingProjection
				  ) 
		,KantataHashColumns	= 
				'' + (
					SELECT STRING_AGG(
						CAST(
							pc.ColumnName AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData pc
					WHERE	CONCAT('Kantata_', REPLACE(REPLACE(REPLACE(PC.TableApiName, 'KimbleOne__', ''), '__c', ''), '_', '')) = p.StagingProjection 
					AND		PC.ColumnName NOT IN ('Id','LastModifiedDate','SystemModstamp','LastModifiedDateTime','Last_Modified_DateTime'
													,'CreatedById','LastModifiedById','Last_Modified_Date__c','LastActivityDate','LastViewedDate')
				  ) 
		,ColumnMapping		= 
				CASE SourceFormat
					WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' + (
					SELECT STRING_AGG(
						CAST(
							'{"source":{"name": "' + pc.ColumnName + '"}' 
								+ ',"sink": {"name": "' + pc.[ColumnName] + '"}}'
							AS NVARCHAR(MAX)
						), ',') 
					FROM ETL.KantataColumnMetaData pc
					WHERE	CONCAT('Kantata_', REPLACE(REPLACE(REPLACE(PC.TableApiName, 'KimbleOne__', ''), '__c', ''), '_', '')) = p.StagingProjection
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
	INNER JOIN Meta.ProcessMap PM ON PM.StagingProjection = P.StagingProjection AND PM.GroupId = 1 
	  CROSS APPLY (
		SELECT 
			  BronzeTableName					= P.TableNameRoot
			, BronzeKantataIdTableName			= IIF(p.TableSchema = 'Kantata', 
													CONCAT(TableNameRoot, '_Id') 
													, NULL) 
			, SilverTableName					= P.TableNameRoot 
	  ) objNames
	  CROSS APPLY (
		SELECT 
			  BronzeTableFqName				= CONCAT('lh_BronzeLayer.bronze.', p.TableSchema, '.', objNames.BronzeTableName )
			, BronzeKantataIdTableFqName		= IIF(p.TableSchema = 'Kantata', 
													CONCAT('lh_BronzeLayer.bronze.',p.TableSchema, '.', objNames.BronzeKantataIdTableName) 
													, NULL) 
			, SilverTableFqName				= CONCAT('lh_SilverLayer.silver.', p.TableSchema, '.', objNames.SilverTableName) 
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

