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

# Parameter Cell
pTargetSchema = "Kantata"
pTargetTable = "BusinessUnit"
pDeltaLakeFolder = "raw/Kantata/BusinessUnit"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# RECOVERY CELL
# Run this manually if the delta table is accidentally dropped.
# Rebuilds the target delta table from ALL parquet files found
# under the staging root for this entity.
# ============================================================

from pyspark.sql.functions import lit
from pyspark.sql import DataFrame
from functools import reduce
from delta.tables import DeltaTable

STAGING_ROOT_PATH = f"Files/{pDeltaLakeFolder}"
TARGET_PATH  = f"Tables/{pTargetSchema}/{pTargetTable}"

print("=" * 60)
print("RECOVERY: Rebuilding delta table from all parquet files")
print(f"  Staging root : {STAGING_ROOT_PATH}")
print(f"  Target       : {pTargetSchema}.{pTargetTable}")
print("=" * 60)

# --- 1. Walk all year/month subfolders and collect parquet paths ---
print("\n[1/4] Scanning for parquet files...")

parquet_paths = []

for year_entry in mssparkutils.fs.ls(STAGING_ROOT_PATH):
    if not year_entry.isDir:
        continue
    for month_entry in mssparkutils.fs.ls(year_entry.path):
        if not month_entry.isDir:
            continue
        for file_entry in mssparkutils.fs.ls(month_entry.path):
            if file_entry.name.endswith(".parquet"):
                parquet_paths.append(file_entry.path)

if not parquet_paths:
    raise FileNotFoundError(f"No parquet files found under {STAGING_ROOT_PATH}. Cannot recover.")

print(f"  Found {len(parquet_paths)} parquet file(s):")
for p in parquet_paths:
    print(f"    {p}")

# --- 2. Read all parquets, unioning with schema evolution ---
print("\n[2/4] Reading and unioning all parquet files...")

# Read each file individually so we can handle schema differences between files
dfs = [spark.read.parquet(p) for p in parquet_paths]

# Union using mergeSchema — adds nulls for columns missing in older files
def union_with_schema_merge(df1: DataFrame, df2: DataFrame) -> DataFrame:
    cols1 = set(df1.schema.fieldNames())
    cols2 = set(df2.schema.fieldNames())

    # Pad df1 with any columns that exist in df2 but not df1
    for field in df2.schema.fields:
        if field.name not in cols1:
            df1 = df1.withColumn(field.name, lit(None).cast(field.dataType))

    # Pad df2 with any columns that exist in df1 but not df2
    for field in df1.schema.fields:
        if field.name not in cols2:
            df2 = df2.withColumn(field.name, lit(None).cast(field.dataType))

    # Reorder df2 columns to match df1 before unioning
    df2 = df2.select(df1.columns)

    return df1.union(df2)

df_all = reduce(union_with_schema_merge, dfs)

print(f"  Total rows   : {df_all.count()}")
print(f"  Total columns: {df_all.schema.fieldNames()}")

# --- 3. Confirm target table is gone before writing ---
print("\n[3/4] Verifying target table is absent...")

if DeltaTable.isDeltaTable(spark, TARGET_PATH):
    raise RuntimeError(
        f"Target table already exists at {TARGET_PATH}. "
        "This recovery cell should only be run when the table has been dropped. "
        "Aborting to avoid duplicate data."
    )

print("  Confirmed — target table does not exist. Proceeding with recovery write.")

# --- 4. Write as a new delta table ---
print("\n[4/4] Writing recovered delta table...")

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {pTargetSchema}")

(
    df_all.write
    .format("delta")
    .mode("overwrite")   # safe here — we confirmed table doesn't exist above
    .option("mergeSchema", "true")
    .save(TARGET_PATH)
)

spark.sql(f"""
    CREATE TABLE IF NOT EXISTS {pTargetSchema}.`{pTargetTable}`
    USING DELTA
    LOCATION '{TARGET_PATH}'
""")

print("\n" + "=" * 60)
print("Recovery complete.")
print(f"  Target table : {pTargetSchema}.{pTargetTable}")
print(f"  Rows written : {df_all.count()}")
print("=" * 60)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
