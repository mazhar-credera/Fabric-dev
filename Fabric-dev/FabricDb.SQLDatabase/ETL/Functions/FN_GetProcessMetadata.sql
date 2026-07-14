CREATE   
    FUNCTION ETL.FN_GetProcessMetadata
(@stagingProjection VARCHAR (512), @ProcessPath VARCHAR (512) /*
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_Resource', 'pl_IngestSalesforce')
SELECT * FROM ETL.FN_GetProcessMetadata('BC_BrightGen_bankAccountLedgerEntries', 'pl_IngestBc365')
SELECT * FROM ETL.FN_GetProcessMetadata('Kantata_Resource', 'pl_LoadSilverFromBronze')
SELECT * FROM ETL.FN_GetProcessMetadata('Internal_DimDate', '[Internal].[usp_Update_DimDate]')
*/)
RETURNS TABLE 
AS
RETURN 
    SELECT PM.ProcessId,
           P.StagingProjection,
           IngestFirstTime  = COALESCE(P.IngestFirstTime, 0) ,
           PM.ProcessPath,
           P.IngestPattern,
           P.PrimaryKeys,
           PrimaryKeysJson      = CONCAT('["', P.PrimaryKeys, '"]') ,
           P.DeltaLakeSourceFolder,
           DeltaLakeBronzeFolder = P.DeltaLakeSourceFolder ,
           objNames.DeltaLakeSilverFolder,
           P.ApiEndPoint,
           P.SourceFormat,
           P.TableSchema,
           PM.CurrentWatermark /*Bronze*/,
           P.WatermarkColumnName,
           PM.BronzeWatermarkValue,
           P.BronzeDataLoadWatermarkColumn,
           objNames.BronzeTableName,
           BronzeTablePath          = CONCAT(P.TableSchema, '/', objNames.BronzeTableName) ,
           objNames.BronzeTableShortcut,
           BronzeTableShortcutPath  = REPLACE(objNames.BronzeTableShortcut, '.', '/') 
           /*Kantata*/ ,
           objNames.BronzeKantataIdTableName,
           fqObjNames.BronzeTableShortcutFqname,
           fqObjNames.BronzeKantataIdTableFqName 
           /*Bc365*/,
           objNames.BronzeBc365IdTableName,
           fqObjNames.BronzeBc365IdTableFqName 
           /*Bronze*/ 
           /*Silver*/,
           objNames.SilverTableName,
           PM.SilverWatermarkValue,
           SilverTablePath          = REPLACE(objNames.SilverTableName, '.', '/') ,
           fqObjNames.SilverTableFqName 
           /*Silver*/,
           P.ModificationTimeStampExpression,
           TransformationsJson      = ISNULL(ST.TransformationsJson, '{}') ,
           KantataSelectColumns = 
                (SELECT STRING_AGG(CAST (PC.ColumnName AS NVARCHAR (MAX)), ',')
                 FROM   ETL.KantataColumnMetaData AS PC
                 WHERE  PC.StagingProjection = P.StagingProjection),

            Bc365SelectColumns  = 
                (SELECT STRING_AGG(CAST (PC.ColumnName AS NVARCHAR (MAX)), ',')
                 FROM   ETL.Bc365ColumnMetadata AS PC
                 WHERE  P.StagingProjection LIKE '%' + PC.ApiEntitySetName) ,

           KantataHashColumns    = 
                (SELECT STRING_AGG(CAST (PC.ColumnName AS NVARCHAR (MAX)), ',')
                 FROM   ETL.KantataColumnMetaData AS PC
                 WHERE  PC.StagingProjection = P.StagingProjection
                        AND PC.ColumnName NOT IN ('Id', 'LastModifiedDate', 'SystemModstamp', 'LastModifiedDateTime', 'Last_Modified_DateTime', 
                                                    'CreatedById', 'LastModifiedById', 'Last_Modified_Date__c', 'LastActivityDate', 'LastViewedDate', 'LengthOfService__c' /*Kimble_Resource */
                                                       , '_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime')
                                                 )  ,
           Bc365HashColumns = 
                (SELECT STRING_AGG(CAST (PC.ColumnName AS NVARCHAR (MAX)), ',')
                 FROM   ETL.Bc365ColumnMetadata AS PC
                 WHERE  P.StagingProjection LIKE '%' + PC.ApiEntitySetName
                        AND PC.ColumnName NOT IN ('id', 'lastModifiedDateTime')) ,

            KantataHashColumnsJson = 
                (SELECT JSON_QUERY(
                            CONCAT(
                                '[', 
                                STRING_AGG(
                                    CAST(
                                        CONCAT('"', REPLACE(PC.ColumnName, '"', '\"'), '"') 
                                        AS NVARCHAR(MAX)
                                    ), 
                                    ','
                                ), 
                                ']'
                            )
                        ) 
                 FROM   ETL.KantataColumnMetaData AS PC
                 WHERE  PC.StagingProjection = P.StagingProjection
                        AND PC.ColumnName NOT IN (
                            'Id', 'LastModifiedDate', 'SystemModstamp', 'LastModifiedDateTime', 'Last_Modified_DateTime', 
                            'CreatedById', 'LastModifiedById', 'Last_Modified_Date__c', 'LastActivityDate', 'LastViewedDate', 'LengthOfService__c' /*Kimble_Resource*/
                            ,'_crda_SourceFileName', '_crda_SourceExecutionId', '_crda_SourceExecutionDateTime'
                        )
                ),           

            Bc365HashColumnsJson = 
                (SELECT JSON_QUERY(
                            CONCAT(
                                '[', 
                                STRING_AGG(
                                    CAST(
                                        CONCAT('"', REPLACE(PC.ColumnName, '"', '\"'), '"') 
                                        AS NVARCHAR(MAX)
                                    ), 
                                    ','
                                ), 
                                ']'
                            )
                        )
                    FROM   ETL.Bc365ColumnMetadata AS PC
                    WHERE  P.StagingProjection LIKE CONCAT('%', PC.ApiEntitySetName)
                        AND PC.ColumnName NOT IN ('id', 'lastModifiedDateTime')
                ),

            KantataColumnMapping = 
                    CASE SourceFormat WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' 
                            + (SELECT STRING_AGG(
                                        CAST ('{"source":{"name": "' + PC.ColumnName + '"}' 
                                            + ',"sink": {"name": "' + PC.[ColumnName] + '"}}' AS NVARCHAR (MAX)), ',')
                                FROM   ETL.KantataColumnMetaData AS PC
                                WHERE  PC.StagingProjection = P.StagingProjection) 
                            + ',{"source":{"name":"_crda_SourceFileName"},"sink":{"name": "_crda_SourceFileName"}}' 
                            + ',{"source":{"name":"_crda_SourceExecutionId"},"sink":{"name": "_crda_SourceExecutionId"}}' 
                            + ',{"source":{"name":"_crda_BronzeLoadDateTime"},"sink":{"name": "_crda_BronzeLoadDateTime"}}' 
                            + ']' 
                            + ',"typeConversion": true,"typeConversionSettings":{"allowDataTruncation": false,"treatBooleanAsNumber": false}}' 
                    END,


            Bc365IngestColumnMapping = 
                CASE SourceFormat WHEN 'Parquet' THEN 
                    CONCAT(
                        '{"type": "TabularTranslator","mappings": [',
                        ( 
                            SELECT STRING_AGG(
                                        CAST(
                                            CONCAT(
                                                --'{"source":{"path": "$[', CHAR(39),PC.ColumnName, CHAR(39),']"}',
                                                '{"source":{"path": "' + PC.ColumnName + '"}',
                                                ',"sink": {"name": "', PC.[ColumnName], '", "type": "',
                                                CASE
                                                    WHEN PC.DataType LIKE 'Microsoft.NAV.%' THEN 'String'
                                                    --WHEN PC.DataType = 'Decimal' THEN 'Double'
                                                    ELSE PC.DataType
                                                END, 
                                                '"}}'
                                            ) 
                                        AS NVARCHAR(MAX)), 
                                        ','
                                    )
                            FROM ETL.Bc365ColumnMetadata AS PC
                            WHERE P.TableNameRoot = PC.ApiEntitySetName
                        ),
                        ']',
                        ',"typeConversion": true,"typeConversionSettings":{"allowDataTruncation": false,"treatBooleanAsNumber": false}',
                        CASE 
                            WHEN NULLIF(p.SourceCollectionReference, '') IS NULL THEN ''
                            ELSE CONCAT(
                                ',"collectionReference":"$[''', 
                                REPLACE(REPLACE(p.SourceCollectionReference, '.', ''']['''), '[0]'']', '''][0]'), 
                                ''']"'
                            )
                        END,
                        ',"mapComplexValuesToString":true}'
                    )
                END,

/*
            Bc365IngestColumnMapping = 
                CASE SourceFormat WHEN 'Parquet' THEN 
                    CONCAT(
                        '{"typeConversion": true,"typeConversionSettings":{"allowDataTruncation": false,"treatBooleanAsNumber": false}',
                        CASE 
                            WHEN NULLIF(p.SourceCollectionReference, '') IS NULL THEN ''
                            ELSE CONCAT(
                                ',"collectionReference":"$[''', 
                                REPLACE(REPLACE(p.SourceCollectionReference, '.', ''']['''), '[0]'']', '''][0]'), 
                                ''']"'
                            )
                        END,
                        ',"mapComplexValuesToString":true}'
                    )
                END,
*/
            Bc365Ingest_IdsOnly_ColumnMapping = 
                CASE SourceFormat WHEN 'Parquet' THEN 
                    CONCAT(
                        '{"type": "TabularTranslator"',
                        CASE 
                            WHEN NULLIF(p.SourceCollectionReference, '') IS NULL THEN ''
                            ELSE CONCAT(
                                ',"collectionReference":"$[''', 
                                REPLACE(REPLACE(p.SourceCollectionReference, '.', ''']['''), '[0]'']', '''][0]'), 
                                ''']"'
                            )
                        END,
                        ',"mapComplexValuesToString":true',
                        ',"mappings": [',
                        ( 
                            SELECT STRING_AGG(
                                       CAST(
                                           CONCAT(
                                               --'{"source":{"path": "$[', CHAR(39),PC.ColumnName, CHAR(39),']"}',
                                                '{"source":{"path": "[' + PC.ColumnName + ']"}',
                                               ',"sink": {"name": "', PC.[ColumnName], '", "type": "',
                                               CASE
                                                   WHEN PC.DataType LIKE 'Microsoft.NAV.%' THEN 'String'
                                                   --WHEN PC.DataType = 'Decimal' THEN 'Double'
                                                   ELSE PC.DataType
                                               END, 
                                               '"}}'
                                           ) 
                                       AS NVARCHAR(MAX)), 
                                       ','
                                   )
                            FROM    ETL.Bc365ColumnMetadata AS PC
                            WHERE   P.TableNameRoot = PC.ApiEntitySetName
                            AND     PC.ColumnName = 'id'
                        ),
                        ']',
                        ',"typeConversion": true,"typeConversionSettings":{"allowDataTruncation": false,"treatBooleanAsNumber": false}}'
                    )
                 END,

/*
           Bc365IngestColumnMapping   = 
                    CASE SourceFormat WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' 
                            + ( SELECT STRING_AGG(CAST ('{"source":{"name": "' + PC.ColumnName + '"}' + ',"sink": {"name": "' + PC.[ColumnName] + '"}}' AS NVARCHAR (MAX)), ',')
                                FROM   ETL.Bc365ColumnMetadata AS PC
                                WHERE  P.StagingProjection LIKE '%' + PC.ApiEntitySetName) 
                            + ',{"source":{"name":"_crda_SourceFileName"},"sink":{"name": "_crda_SourceFileName"}}' 
                            + ',{"source":{"name":"_crda_SourceExecutionId"},"sink":{"name": "_crda_SourceExecutionId"}}' 
                            + ',{"source":{"name":"BcCompanyName"},"sink":{"name": "BcCompanyName"}}' 
                            + ',{"source":{"name":"_crda_BronzeLoadDateTime"},"sink":{"name": "_crda_BronzeLoadDateTime"}}' 
                            + ']' 
                            + COALESCE (',"collectionReference":"$[''' 
                            + REPLACE(REPLACE(NULLIF (p.SourceCollectionReference, ''), '.', ''']['''), '[0]'']', '''][0]') + ''']"', '') 
                            + ',"mapComplexValuesToString":true}' 
                     END,

           Bc365IngestColumnMapping   = 
                    CASE SourceFormat WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' 
                            + ( SELECT STRING_AGG(
                                            CAST (  '{"source":{"name": "' + PC.ColumnName + '"}' 
                                                    + ',"sink": {"name": "' + PC.[ColumnName] + '", "type": "' 
                                                        + CASE
                                                            WHEN PC.DataType LIKE 'Microsoft.NAV.%' THEN 'String'
                                                            WHEN PC.DataType = 'Decimal' THEN 'Double'
                                                            ELSE PC.DataType
                                                          END + '"}}' 
                                            AS NVARCHAR (MAX)), ','
                                       )
                                FROM   ETL.Bc365ColumnMetadata AS PC
                                WHERE  P.StagingProjection LIKE '%' + PC.ApiEntitySetName) 
                            + ']' 
                            + COALESCE (',"collectionReference":"$[''' 
                            + REPLACE(REPLACE(NULLIF (p.SourceCollectionReference, ''), '.', ''']['''), '[0]'']', '''][0]') + ''']"', '') 
                            + ',"mapComplexValuesToString":true}' 
                     END,

            Bc365IngestColumnMapping = 
                CASE SourceFormat WHEN 'Parquet' THEN 
                    CONCAT(
                        '{"type": "TabularTranslator","mappings": [',
                        ( 
                            SELECT STRING_AGG(
                                       CAST(
                                           CONCAT(
                                               '{"source":{"path": "', 
                                               -- Inject '$' for root properties if no collectionReference exists
                                               CASE WHEN NULLIF(P.SourceCollectionReference, '') IS NULL THEN '$' ELSE '' END,
                                               '[''', PC.ColumnName, ''']"},"sink": {"name": "', 
                                               PC.ColumnName, 
                                               '", "type": "',
                                               CASE
                                                   WHEN PC.DataType LIKE 'Microsoft.NAV.%' THEN 'String'
                                                   WHEN PC.DataType = 'Decimal' THEN 'Double'
                                                   ELSE PC.DataType
                                               END, 
                                               '"}}'
                                           ) 
                                       AS NVARCHAR(MAX)), 
                                       ','
                                   )
                            FROM ETL.Bc365ColumnMetadata AS PC
                            WHERE P.TableNameRoot = PC.ApiEntitySetName
                        ),
                        ']',
                        CASE 
                            WHEN NULLIF(P.SourceCollectionReference, '') IS NULL THEN ''
                            ELSE CONCAT(
                                ',"collectionReference":"$[''', 
                                REPLACE(REPLACE(P.SourceCollectionReference, '.', ''']['''), '[0]'']', '''][0]'), 
                                ''']"'
                            )
                        END,
                        ',"mapComplexValuesToString":true}'
                    )
                END,
*/
/*
        Bc365IngestColumnMapping = 
            CASE SourceFormat WHEN 'Parquet' THEN 
                CONCAT(
                    '{"type": "TabularTranslator"',
                    CASE 
                        WHEN NULLIF(p.SourceCollectionReference, '') IS NULL THEN ''
                        ELSE CONCAT(
                            ',"collectionReference":"$[''', 
                            REPLACE(REPLACE(p.SourceCollectionReference, '.', ''']['''), '[0]'']', '''][0]'), 
                            ''']"'
                        )
                    END,
                    ',"mapComplexValuesToString":true}'
                )
            END,

            Bc365IngestColumnMapping = 
                CASE SourceFormat WHEN 'Parquet' THEN 
                    CONCAT(
                        '{"type": "TabularTranslator","mappings": []', -- Kept an empty array to prevent KeyNotFoundException
                        CASE 
                            WHEN NULLIF(p.SourceCollectionReference, '') IS NULL THEN ''
                            ELSE CONCAT(
                                ',"collectionReference":"$[''', 
                                REPLACE(REPLACE(p.SourceCollectionReference, '.', ''']['''), '[0]'']', '''][0]'), 
                                ''']"'
                            )
                        END,
                        ',"mapComplexValuesToString":true}'
                    )
                END,
*/
/*
            Bc365Ingest_IdsOnly_ColumnMapping   = 
                    CASE SourceFormat WHEN 'Parquet' THEN '{"type": "TabularTranslator","mappings": [' 
                            + ( SELECT STRING_AGG(
                                            CAST (  '{"source":{"path": "[' + PC.ColumnName + ']"}' 
                                                    + ',"sink": {"name": "' + PC.[ColumnName] + '", "type": "' 
                                                        + CASE
                                                            WHEN PC.DataType LIKE 'Microsoft.NAV.%' THEN 'String'
                                                            WHEN PC.DataType = 'Decimal' THEN 'Double'
                                                            ELSE PC.DataType
                                                          END + '"}}' 
                                            AS NVARCHAR (MAX)), ','
                                       )
                                FROM    ETL.Bc365ColumnMetadata AS PC
                                WHERE   P.TableNameRoot = PC.ApiEntitySetName
                                AND     PC.ColumnName = 'id') 
                            + ']' 
                            + COALESCE (',"collectionReference":"$[''' 
                            + REPLACE(REPLACE(NULLIF (p.SourceCollectionReference, ''), '.', ''']['''), '[0]'']', '''][0]') + ''']"', '') 
                            + ',"mapComplexValuesToString":true}' 
                     END,
*/

           SharePointDomain = IIF (P.TableSchema = 'SharePoint', SP.SharePointDomain, NULL),
           SharePointSite   = IIF (P.TableSchema = 'SharePoint', SP.SharePointSite, NULL),
           SharePointOnlineListName = IIF (P.TableSchema = 'SharePoint', SP.SharePointOnlineListName, NULL) 

    FROM   Meta.Process         P 
    LEFT JOIN   ETL.ProcessMap  PM  ON  PM.StagingProjection = P.StagingProjection
                                    AND PM.ProcessPath = @ProcessPath
    LEFT JOIN   ETL.SilverTransformations ST    ON  ST.StagingProjection = P.StagingProjection 
    CROSS APPLY (
                SELECT P.TableNameRoot AS BronzeTableName,
                       IIF (P.TableSchema = 'Kantata', CONCAT(TableNameRoot, '_Id'), NULL) AS BronzeKantataIdTableName,
                       IIF (P.TableSchema = 'BC', CONCAT(TableNameRoot, '_Id'), NULL) AS BronzeBc365IdTableName,
                       CONCAT('Bronze', P.TableSchema, '.', P.TableNameRoot) AS BronzeTableShortcut,
                       CONCAT(P.TableSchema, '.', 'HISTORY_', P.TableNameRoot) AS SilverTableName,
                       REPLACE(REPLACE(P.DeltaLakeSourceFolder, P.TableNameRoot, CONCAT('HISTORY_', P.TableNameRoot)), 'bronze', 'silver') AS DeltaLakeSilverFolder
                ) AS objNames 

    CROSS APPLY (
                SELECT CONCAT('lh_BronzeLayer.', P.TableSchema, '.', objNames.BronzeTableName) AS BronzeTableFqName,
                       IIF (P.TableSchema = 'Kantata', CONCAT('lh_BronzeLayer.', P.TableSchema, '.', objNames.BronzeKantataIdTableName), NULL) AS BronzeKantataIdTableFqName,
                       IIF (P.TableSchema = 'BC', CONCAT('lh_BronzeLayer.', P.TableSchema, '.', objNames.BronzeBc365IdTableName), NULL) AS BronzeBc365IdTableFqName,
                       CONCAT('lh_SilverLayer.', 'Bronze', P.TableSchema, '.', P.TableNameRoot) AS BronzeTableShortcutFqname,
                       CONCAT('lh_SilverLayer.', objNames.SilverTableName) AS SilverTableFqName
                ) AS fqObjNames 

    OUTER APPLY (
                SELECT MAX(IIF (D.ordinal = 1, D.[value], NULL)) AS SharePointDomain,
                       MAX(IIF (D.ordinal = 2, D.[value], NULL)) AS SharePointSite,
                       MAX(IIF (D.ordinal = 3, D.[value], NULL)) AS SharePointOnlineListName
                FROM   string_split (P.ApiEndPoint, '\', 1) AS D) AS SP

    WHERE  P.StagingProjection = @stagingProjection
           AND P.IsActive = 1
    UNION ALL
    SELECT PM.ProcessId,
           PM.StagingProjection,
           NULL AS IngestFirstTime , 
           PM.ProcessPath,
           NULL AS IngestPattern,
           NULL AS PrimaryKeys,
           NULL AS PrimaryKeysJson,
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



/*
raw/Kantata/BusinessUnit/2026/02
25-105841.parquet
*/

GO

