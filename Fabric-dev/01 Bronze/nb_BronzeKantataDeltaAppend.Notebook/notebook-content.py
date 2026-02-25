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
pParquetFile = "25-125827.parquet"
pDeltaLakeFolder = "raw/Kantata/BusinessUnit/2026/02"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
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

print("=" * 60)
print("Schema-drift-safe delta append")
print(f"  Source : {PARQUET_PATH}")
print(f"  Target : {pTargetSchema}.{pTargetTable}")
print("=" * 60)

# --- 1. Read incoming parquet ---
print("\n[1/5] Reading source parquet...")
df_new = spark.read.parquet(PARQUET_PATH)
print(f"  Rows   : {df_new.count()}")
print(f"  Columns: {df_new.schema.fieldNames()}")

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

print("\n" + "=" * 60)
print("Append complete.")
print(f"  Target table : {pTargetSchema}.{pTargetTable}")
print(f"  Rows written : {df_new.count()}")
print("=" * 60)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
