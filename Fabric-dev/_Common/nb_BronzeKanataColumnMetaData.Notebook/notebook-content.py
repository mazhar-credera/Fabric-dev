# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "c6eb7c0f-f0ac-4fc4-87c1-13b09e22841c",
# META       "default_lakehouse_name": "lh_BronzeLayer",
# META       "default_lakehouse_workspace_id": "29f8113f-2a90-401e-a4f7-d6121b481419",
# META       "known_lakehouses": [
# META         {
# META           "id": "c6eb7c0f-f0ac-4fc4-87c1-13b09e22841c"
# META         }
# META       ]
# META     }
# META   }
# META }

# PARAMETERS CELL ********************

# Parameters 
# Type here in the cell editor to add code!
pSchemaName = "Kantata"
pTableName = "ColumnMetaData"
pDeltaLakeFolder = "tmp/Kantata/_ColumnMetaData"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Load all the files into one python data frame
combined_df = spark.read.format("parquet").load(f"Files/{pDeltaLakeFolder}")

(
    combined_df.write
    .format("delta")
    .mode("overwrite")   # safe here — we confirmed table doesn't exist above
    .option("mergeSchema", "true")
    .save(f"Tables/{pSchemaName}/{pTableName}")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
