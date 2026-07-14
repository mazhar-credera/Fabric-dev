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
pTargetSchema = "Kantata"
pTargetTable = "BusinessUnit"
pParquetFile = "05-115730.parquet"
pDeltaLakeFolder = "raw/bronze/Kantata/BusinessUnit/2026/03"
pWatermarkColumnName = "SystemModstamp"
pBronzeWatermarkValue= "2000-01-01"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Force a Metadata Refresh / force the SQL endpoint to sync the specific table
#sandbox cell
#query = f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`"
#spark.sql(query)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

# ============================================================
# Schema-Drift-Safe Delta Append
# Bronze Lakehouse | Parameterised
# ============================================================

from pyspark.sql.functions import lit
from delta.tables import DeltaTable

# ============================================================
# DERIVED PATHS
# Notebook is attached to the Bronze lakehouse so we use
# the default lakehouse path via the well-known OneLake URI.
# ============================================================

# Build the full parquet source path
PARQUET_PATH = f"Files/{pDeltaLakeFolder}/{pParquetFile}"

# Build the target delta table path (Tables/ is the managed Delta area)
TARGET_PATH  = f"Tables/{pTargetSchema}/{pTargetTable}"

# ============================================================
# HELPER: cast incoming columns to match existing target types
# ============================================================

def align_types(df_new, existing_schema):
    for field in existing_schema.fields:
        if field.name in df_new.schema.fieldNames():
            incoming_type = df_new.schema[field.name].dataType
            if incoming_type != field.dataType:
                print(f"  [TYPE DRIFT]  Column '{field.name}': {incoming_type} → casting to {field.dataType}")
                df_new = df_new.withColumn(field.name, df_new[field.name].cast(field.dataType))
    return df_new

# ============================================================
# HELPER: pad missing target columns with nulls
# ============================================================

def add_missing_columns(df_new, existing_schema):
    for field in existing_schema.fields:
        if field.name not in df_new.schema.fieldNames():
            print(f"  [COL REMOVED] Column '{field.name}' missing from source — writing nulls")
            df_new = df_new.withColumn(field.name, lit(None).cast(field.dataType))
    return df_new

# ============================================================
# MAIN
# ============================================================
final_output = None
df_clean = None  # <-- Initialize this so we can track if cleaning occurred
try:
    print("=" * 60)
    print("Schema-drift-safe delta append")
    print(f"  Source : {PARQUET_PATH}")
    print(f"  Target : {pTargetSchema}.{pTargetTable}")
    print("=" * 60)

    # --- Remove the "value." prefix from the column names
        # --- Issue only with BC parquet files 
    if pTargetSchema == 'BC':
        # 1. Force the parameter to be a clean string to prevent any 'set' errors
        folder_str = str(pDeltaLakeFolder).strip()

        # 2. Dynamically construct your paths
        original_path = f"Files/{folder_str}/{pParquetFile}"

        # This strips 'raw/bronze/' from the start and prepends 'tmp/'
        clean_suffix = folder_str.removeprefix("raw/bronze/").lstrip("/")
        temp_folder_path = f"Files/tmp/{clean_suffix}"
        temp_file_path = f"{temp_folder_path}/{pParquetFile}_temp"

        # 3. Read the Parquet file
        df = spark.read.parquet(original_path)

        # 4. Apply the column rename map
        rename_map = {
            col_name: col_name[6:] 
            for col_name in df.columns 
            if col_name.startswith("value.")
        }
        df_clean = df.withColumnsRenamed(rename_map)

        # 5. Write the clean data to the temp folder
        df_clean.coalesce(1).write.mode("overwrite").parquet(temp_file_path)

        # 6. Swap the files using Fabric Utilities (mssparkutils)
        temp_files = mssparkutils.fs.ls(temp_file_path)
        actual_parquet_file = [f.path for f in temp_files if f.name.endswith(".parquet")][0]

        # Safely delete the uncleaned original file
        mssparkutils.fs.rm(original_path, recurse=True)

        # Move the clean file to replace the original file
        mssparkutils.fs.mv(actual_parquet_file, original_path)

        # Clean up the temporary directory
        mssparkutils.fs.rm(temp_folder_path, recurse=True)
        
        # --- FIX 1: Clear Spark's schema cache for files
        spark.catalog.clearCache()

        print(f"Successfully cleaned and replaced: {original_path}")


    # --- 1. Read incoming parquet ---
    print("\n[1/5] Reading source parquet...")
    
    # --- FIX 2: Use the already-loaded clean DataFrame to bypass disk read and schema caching bugs
    if df_clean is not None:
        print("  Re-using already cleaned DataFrame from memory...")
        df_new = df_clean
    else:
        df_new = spark.read.parquet(PARQUET_PATH)
        
    print(f"  Rows   : {df_new.count()}")
    print(f"  Columns: {df_new.schema.fieldNames()}")

    if not df_new.isEmpty():

        # --- 2. Check whether target Delta table already exists ---
        print("\n[2/5] Checking target delta table...")

        if DeltaTable.isDeltaTable(spark, TARGET_PATH):
            print("  Target table EXISTS — performing schema comparison")
            existing_schema = spark.read.format("delta").load(TARGET_PATH).schema
            target_cols     = set(existing_schema.fieldNames())
            source_cols     = set(df_new.schema.fieldNames())

            new_cols     = source_cols - target_cols
            dropped_cols = target_cols - source_cols

            # --- 3. Report drift ---
            print(f"\n[3/5] Schema drift summary:")
            print(f"  New columns in source (will be added to target) : {new_cols     if new_cols     else 'None'}")
            print(f"  Columns dropped from source (nulls written)     : {dropped_cols if dropped_cols else 'None'}")

            # --- 4. Align types and pad missing columns ---
            print("\n[4/5] Aligning schema...")
            df_new = align_types(df_new, existing_schema)
            df_new = add_missing_columns(df_new, existing_schema)

        else:
            print("Target table does NOT exist — will be created on first write")
            print("[3/5] Skipping schema comparison (first load)")
            print("[4/5] Skipping type alignment (first load)")

        # --- 5. Ensure schema exists then append ---
        print("\n[5/5] Appending to delta table...")

        spark.sql(f"CREATE SCHEMA IF NOT EXISTS {pTargetSchema}")

        (
            df_new.write
            .format("delta")
            .mode("append")
            .option("mergeSchema", "true")
            .save(TARGET_PATH)
        )

        # Register the table in the metastore preserving case, if it doesn't exist yet
        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS {pTargetSchema}.`{pTargetTable}`
            USING DELTA
            LOCATION '{TARGET_PATH}'
        """)

        # Force a Metadata Refresh / force the SQL endpoint to sync the specific table
        query = f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`"
        spark.sql(query)

        print("\n" + "=" * 60)
        print("Append complete.")
        print(f"  Target table : {pTargetSchema}.{pTargetTable}")
        print(f"  Rows written : {df_new.count()}")
        print("=" * 60)

        # ------------------------------------------------------------
        # NEW: Calculate Watermark and Exit with Value
        # ------------------------------------------------------------
        print("\n[6/6] Calculating Watermark for Pipeline...")
        
        # We query the TARGET_PATH directly to ensure we see the data we just wrote
        watermark_df = spark.sql(f"""
            SELECT COALESCE(MAX({pWatermarkColumnName}), '{pBronzeWatermarkValue}') as BronzeWatermarkValue
            FROM `{pTargetSchema}`.`{pTargetTable}`
        """)
        
        # Store the value in our variable instead of exiting immediately
        final_output = str(watermark_df.collect()[0][0])
        print(f"  Watermark identified: {final_output}")

    else:
        # This handles the case where df_new.isEmpty() is True
        print("No new data found. Returning existing watermark.")
        final_output = str(pBronzeWatermarkValue)

except Exception as e:
    # This only catches REAL errors now
    error_msg = f"FAILURE: {str(e)}"
    print(error_msg)
    mssparkutils.notebook.exit(error_msg)

# ------------------------------------------------------------
# FINAL EXIT (Outside the try/except)
# ------------------------------------------------------------
if final_output:
    mssparkutils.notebook.exit(final_output)
    

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }
