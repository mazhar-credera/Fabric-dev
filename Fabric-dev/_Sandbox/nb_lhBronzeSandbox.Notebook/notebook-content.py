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


# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

parquet_path = "Files/raw/bronze/BC"

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
