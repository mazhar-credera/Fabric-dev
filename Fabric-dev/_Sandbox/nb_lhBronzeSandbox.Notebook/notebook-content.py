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

# CELL ********************

# MAGIC %%sql
# MAGIC /*drop table if exists Kantata.ActivityAssignment
# MAGIC drop table if exists Kantata.ResourcedActivity 
# MAGIC drop table if exists Kantata.ActivityAssignmentDemand */
# MAGIC /*drop table if exists Kantata.Resource*/
# MAGIC /*
# MAGIC SELECT CONCAT(
# MAGIC     'DROP TABLE IF EXISTS ',
# MAGIC     table_schema,
# MAGIC     '.',
# MAGIC     table_name,
# MAGIC     ';'
# MAGIC ) AS drop_statement
# MAGIC FROM information_schema.tables
# MAGIC WHERE table_schema = 'BC';
# MAGIC */
# MAGIC 


# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

#spark.catalog.listTables("BC")

tables = spark.sql("SHOW TABLES IN BC").collect()
#tables = spark.sql("SHOW TABLES IN BC LIKE '*_Id'").collect()

for row in tables:
    table_name = row.tableName
    sql = f"DROP TABLE IF EXISTS BC.{table_name}"
    print(sql)
    spark.sql(sql)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }

# CELL ********************

#parquet_path = "Files/tmp/bronze/Bc"
parquet_path = "Files/raw/bronze/Bc"

# 1. Check if the folder exists before interacting with it
if notebookutils.fs.exists(parquet_path):
    print(f"Folder found. Listing files to be deleted in '{parquet_path}':")
    
    files = notebookutils.fs.ls(parquet_path)
    for file in files:
        print(f" - {file.name}")
    
    # 2. Delete the folder and its contents recursively
    print("\nDeleting folder...")
    notebookutils.fs.rm(parquet_path, recurse=True)
    print("Deletion complete!")
else:
    print(f"Notice: The path '{parquet_path}' does not exist. Nothing to delete.")

# 3. Final Verification
if not notebookutils.fs.exists(parquet_path):
    print("Verification: Folder successfully confirmed as absent.")
else:
    print("Alert: Folder deletion failed; the path still exists.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }

# CELL ********************

# Load the table and filter out the old NULL rows
TARGET_PATH = "Tables/BC/bankAccounts"

df_check = spark.read.format("delta").load(TARGET_PATH)
df_check.filter(df_check.id.isNotNull()).show(10)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

# This will show you the clean rows that were successfully appended!
display(spark.sql("SELECT * FROM BC.salesInvoiceHeaders WHERE id IS NOT NULL LIMIT 10"))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

df = spark.read.parquet(
    "Files/raw/bronze/BC/custLedgerEntries"
)
df.printSchema()

display(
    mssparkutils.fs.ls("Files/raw/bronze/BC/custLedgerEntries")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }
