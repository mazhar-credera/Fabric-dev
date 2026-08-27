CREATE   
    FUNCTION ETL.FN_GetProcessMetadata_2
    (
        @stagingProjection VARCHAR (512), @ProcessPath VARCHAR (512) 
    )
/*
SELECT * FROM ETL.FN_GetProcessMetadata_2('Kantata_Resource', 'pl_IngestSalesforce')
SELECT * FROM ETL.FN_GetProcessMetadata_2('BC_BrightGen_custLedgerEntries', 'pl_IngestBc365')
SELECT * FROM ETL.FN_GetProcessMetadata_2('BC_BrightGen_custLedgerEntries', 'pl_LoadSilverFromBronze')
SELECT * FROM ETL.FN_GetProcessMetadata_2('Kantata_Resource', 'pl_LoadSilverFromBronze')
SELECT * FROM ETL.FN_GetProcessMetadata_2('Internal_DimDate', '[Internal].[usp_Update_DimDate]')
*/
RETURNS TABLE 
AS
RETURN 
    SELECT DISTINCT 
            PM.ProcessId
           ,P.*

    FROM   Meta.Process         P 
    LEFT JOIN   ETL.ProcessMap  PM  ON  PM.ProcessPath = @ProcessPath
                                    AND @stagingProjection = 
                                                        STUFF(
                                                                P.StagingProjection,
                                                                CHARINDEX('_', P.StagingProjection),
                                                                CHARINDEX('_', P.StagingProjection, CHARINDEX('_', P.StagingProjection) + 1) - CHARINDEX('_', P.StagingProjection),
                                                                ''
                                                            )
    
    /*                                    AND P.StagingProjection =CASE 
                                                                WHEN P.TableSchema <> 'BC' THEN @stagingProjection
                                                                ELSE CONCAT(P.TableSchema, '_', P.TableNameRoot)
                                                             END 
*/
    LEFT JOIN   ETL.SilverTransformations ST    ON  ST.StagingProjection = P.StagingProjection 

    WHERE @stagingProjection = 
                        STUFF(
                                P.StagingProjection,
                                CHARINDEX('_', P.StagingProjection),
                                CHARINDEX('_', P.StagingProjection, CHARINDEX('_', P.StagingProjection) + 1) - CHARINDEX('_', P.StagingProjection),
                                ''
                            )
    AND     P.IsActive = 1 

/*
    UNION ALL
    SELECT PM.ProcessId,
           PM.StagingProjection,
           NULL AS IngestFirstTime , 
           PM.ProcessPath,
           NULL AS IngestPattern,
           NULL AS PrimaryKeys,
           NULL AS PrimaryKeysJson,
           NULL AS BcTmpFolderForIds , 
           NULL AS DeltaLakeSourceFolder,
           NULL AS DeltaLakeBronzeFolder,
           NULL AS DeltaLakeSilverFolder,
           NULL AS ApiEndPoint,
           NULL AS SourceFormat,
           NULL AS TableSchema,
           PM.CurrentWatermark /*Bronze*/,
           NULL AS WatermarkColumnName,
           PM.BronzeWatermarkValue,
           NULL AS BronzeDataLoadWatermarkColumn,
           NULL AS BronzeTableName,
           NULL AS BronzeTablePath,
           NULL AS BronzeTableShortcut,
           NULL AS BronzeTableShortcutPath,
           NULL AS BronzeKantataIdTableName,
           NULL AS BronzeTableShortcutFqname,
           NULL AS BronzeKantataIdTableFqName,
           NULL AS BronzeBc365IdTableName,
           NULL /*Bronze*/ /*Silver*/ AS BronzeBc365IdTableFqName,
           NULL AS SilverTableName,
           PM.SilverWatermarkValue,
           NULL AS SilverTablePath,
           NULL /*Silver*/ AS SilverTableFqName,
           NULL AS ModificationTimeStampExpression,
           NULL AS TransformationsJson,
           NULL AS KantataSelectColumns,
           NULL AS Bc365SelectColumns,
           NULL AS KantataHashColumns,
           NULL AS Bc365HashColumns,
           NULL AS KantataHashColumnsJson,
           NULL AS Bc365HashColumnsJson,
           NULL AS KantataColumnMapping,
           NULL AS Bc365IngestColumnMapping,
           NULL AS Bc365Ingest_IdsOnly_ColumnMapping,
           NULL AS SharePointDomain,
           NULL AS SharePointSite,
           NULL AS SharePointOnlineListName
    FROM   ETL.ProcessMap AS PM --CROSS APPLY Meta.Process	P	
    WHERE  PM.StagingProjection = @stagingProjection
           AND PM.ProcessPath = @ProcessPath
           AND PM.ProcessType = 'ASQL'
           AND PM.IsActive = 1
*/


/*
raw/Kantata/BusinessUnit/2026/02
25-105841.parquet
*/

GO

