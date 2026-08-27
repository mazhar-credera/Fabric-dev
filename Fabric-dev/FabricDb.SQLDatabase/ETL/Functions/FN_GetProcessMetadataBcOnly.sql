CREATE   
    FUNCTION ETL.FN_GetProcessMetadataBcOnly 
        ( @ProcessId INT ) 
/*
SELECT * FROM ETL.FN_GetProcessMetadataBcOnly(834)

*/
RETURNS TABLE 
AS
RETURN 
    SELECT PM.ProcessId,
           PM.StagingProjection,
           IngestFirstTime      = COALESCE(PM.IngestFirstTime, 0) ,
           PM.ProcessPath,
           P.IngestPattern,
           P.PrimaryKeys,
           PrimaryKeysJson      = (SELECT CONCAT(
                                            '["',
                                            REPLACE(P.PrimaryKeys, ',', '","'),
                                            '"]'
                                        ) AS JsonArray) ,
           P.SourceFormat,
           P.TableSchema,
           PM.CurrentWatermark /*Bronze*/,
           P.WatermarkColumnName,
           PM.BronzeWatermarkValue,
           P.BronzeDataLoadWatermarkColumn,
           /*Bronze*/
           objNames.BronzeTableName , 
           fqObjNames.BronzeTableFqName ,
           objNames.BronzeTableShortcut,
           fqObjNames.BronzeTableShortcutFqname , 
           BronzeTableShortcutPath  = REPLACE(objNames.BronzeTableShortcut, '.', '/') , 
           BronzeTablePath          = CONCAT(P.TableSchema, '/', objNames.BronzeTableName) ,
           objNames.BronzeBc365IdTableName ,
           fqObjNames.BronzeBc365IdTableFqName, 

           /*Silver*/
           DeltaLakeSilverFolder= CONCAT('raw/silver/', P.TableSchema, '/HISTORY_', P.TableNameRoot) , 
           objNames.SilverTableName,
           PM.SilverWatermarkValue,
           SilverTablePath          = REPLACE(objNames.SilverTableName, '.', '/') ,
           fqObjNames.SilverTableFqName , 
           /*Silver*/

           P.ModificationTimeStampExpression,
           TransformationsJson      = ISNULL(ST.TransformationsJson, '{}') , 

           Bc365SelectColumns  = 
                (SELECT STRING_AGG(CAST (PC.ColumnName AS NVARCHAR (MAX)), ',')
                 FROM   ETL.Bc365ColumnMetadata AS PC
                 WHERE  PM.StagingProjection LIKE '%' + PC.ApiEntitySetName) , 

           Bc365HashColumns = 
                (SELECT STRING_AGG(CAST (PC.ColumnName AS NVARCHAR (MAX)), ',')
                 FROM   ETL.Bc365ColumnMetadata AS PC
                 WHERE  PM.StagingProjection LIKE '%' + PC.ApiEntitySetName
                        AND PC.ColumnName NOT IN ('id', 'lastModifiedDateTime')) , 

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
                    WHERE  PM.StagingProjection LIKE CONCAT('%', PC.ApiEntitySetName)
                        AND PC.ColumnName NOT IN ('id', 'lastModifiedDateTime')
                )

    FROM	ETL.ProcessMap  PM 
    INNER JOIN (
                SELECT  DISTINCT
                        MP.IngestPattern, MP.TableSchema, MP.TableNameRoot, MP.SourceFormat, 
                        MP.SourceCollectionReference, MP.ModificationTimeStampExpression, 
                        MP.WatermarkColumnName, MP.BronzeDataLoadWatermarkColumn, MP.PrimaryKeys 
                FROM    META.Process MP
                WHERE   MP.TableSchema='BC' 
            )   P ON  PM.StagingProjection = CONCAT(P.TableSchema, '_', P.TableNameRoot)
    LEFT JOIN   ETL.SilverTransformations ST    ON  ST.StagingProjection = PM.StagingProjection 
    CROSS APPLY (
                SELECT  BronzeTableName         = P.TableNameRoot,
                        BronzeBc365IdTableName  = IIF (P.TableSchema = 'BC', CONCAT(TableNameRoot, '_Id'), NULL) ,
                        BronzeTableShortcut     = CONCAT('Bronze', P.TableSchema, '.', P.TableNameRoot) ,
                        SilverTableName         = CONCAT(P.TableSchema, '.', 'HISTORY_', P.TableNameRoot) 
                ) AS objNames 

    CROSS APPLY (
                SELECT  BronzeTableFqName        = CONCAT('lh_BronzeLayer.', P.TableSchema, '.', objNames.BronzeTableName) ,
                        BronzeBc365IdTableFqName = IIF (P.TableSchema = 'BC', CONCAT('lh_BronzeLayer.', P.TableSchema, '.', objNames.BronzeBc365IdTableName), NULL) ,
                        BronzeTableShortcutFqname= CONCAT('lh_SilverLayer.', 'Bronze', P.TableSchema, '.', P.TableNameRoot) ,
                        SilverTableFqName        = CONCAT('lh_SilverLayer.', objNames.SilverTableName)
                ) AS fqObjNames 

    WHERE	PM.IsActive = 1     
    /*AND     PM.GroupId = 2 */
    AND		PM.SourceSystem = 'BC' 
    AND     PM.ProcessId    = @ProcessId 

/*
raw/Kantata/BusinessUnit/2026/02
25-105841.parquet
*/

GO

