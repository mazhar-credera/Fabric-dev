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
pDeltaLakeFolder = "raw/bronze/Kantata/BusinessUnit"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC DROP TABLE IF EXISTS Kantata.BusinessUnit

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

import time
import traceback
from datetime import datetime, timezone
from pyspark.sql.functions import lit
from pyspark.sql import DataFrame
from functools import reduce
from delta.tables import DeltaTable


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

STAGING_ROOT_PATH = f"Files/{pDeltaLakeFolder}"
TARGET_PATH  = f"Tables/{pTargetSchema}/{pTargetTable}"

# ------------------------------------------------------------
# Debug helpers
# ------------------------------------------------------------
DEBUG = True   # set False to silence [DEBUG] lines

_run_start = time.time()

def _ts() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

def dbg(msg: str) -> None:
    if DEBUG:
        elapsed = time.time() - _run_start
        print(f"[DEBUG {_ts()} +{elapsed:7.2f}s] {msg}")

# ============================================================
# MAIN
# ============================================================
should_exit_success = False
exit_message = ""
try:

    print("=" * 60)
    print("RECOVERY: Rebuilding delta table from all parquet files")
    print(f"  Staging root : {STAGING_ROOT_PATH}")
    print(f"  Target       : {pTargetSchema}.{pTargetTable}")
    print(f"  Target path  : {TARGET_PATH}")
    print(f"  Spark version: {spark.version}")
    print("=" * 60)
    dbg("Recovery started.")

    # --- 1. Confirm target table is gone before doing any work ---
    # Fail fast: check absence before scanning/reading to avoid wasted work.
    print("\n[1/4] Verifying target table is absent...")
    dbg(f"Checking DeltaTable.isDeltaTable({TARGET_PATH})...")

    if DeltaTable.isDeltaTable(spark, TARGET_PATH):
        raise RuntimeError(
            f"Target table already exists at {TARGET_PATH}. "
            "This recovery cell should only be run when the table has been dropped. "
            "Aborting to avoid duplicate data."
        )

    print("  Confirmed — target table does not exist. Proceeding with recovery.")
    dbg("Target table absent — safe to continue.")

    # --- 2. Walk all year/month subfolders and collect parquet paths ---
    print("\n[2/4] Scanning for parquet files...")
    dbg(f"Listing staging root: {STAGING_ROOT_PATH}")

    parquet_paths = []

    for year_entry in mssparkutils.fs.ls(STAGING_ROOT_PATH):
        if not year_entry.isDir:
            dbg(f"Skipping non-dir at root level: {year_entry.name}")
            continue
        dbg(f"Descending into year folder: {year_entry.name}")
        for month_entry in mssparkutils.fs.ls(year_entry.path):
            if not month_entry.isDir:
                dbg(f"  Skipping non-dir at year level: {month_entry.name}")
                continue
            dbg(f"  Descending into month folder: {year_entry.name}/{month_entry.name}")
            month_file_count = 0
            for file_entry in mssparkutils.fs.ls(month_entry.path):
                if file_entry.name.endswith(".parquet"):
                    parquet_paths.append(file_entry.path)
                    month_file_count += 1
                else:
                    dbg(f"    Ignoring non-parquet: {file_entry.name}")
            dbg(f"  {year_entry.name}/{month_entry.name}: {month_file_count} parquet file(s)")

    dbg(f"Scan complete. Total parquet files found: {len(parquet_paths)}")

    if parquet_paths:

        print(f"  Found {len(parquet_paths)} parquet file(s):")
        for p in parquet_paths:
            print(f"    {p}")

        # --- 3. Read all parquets, unioning with schema evolution ---
        print("\n[3/4] Reading and unioning all parquet files...")

        # Read each file individually so we can handle schema differences between files
        dbg("Reading each parquet file into its own DataFrame...")
        dfs = []
        for idx, p in enumerate(parquet_paths, start=1):
            df_p = spark.read.parquet(p)
            dbg(f"  [{idx}/{len(parquet_paths)}] {p} -> {len(df_p.columns)} cols: {df_p.columns}")
            dfs.append(df_p)

        # Union using mergeSchema — adds nulls for columns missing in older files
        def union_with_schema_merge(df1: DataFrame, df2: DataFrame) -> DataFrame:
            cols1 = set(df1.schema.fieldNames())
            cols2 = set(df2.schema.fieldNames())

            added_to_df1 = []
            for field in df2.schema.fields:
                if field.name not in cols1:
                    df1 = df1.withColumn(field.name, lit(None).cast(field.dataType))
                    added_to_df1.append(field.name)

            added_to_df2 = []
            for field in df1.schema.fields:
                if field.name not in cols2:
                    df2 = df2.withColumn(field.name, lit(None).cast(field.dataType))
                    added_to_df2.append(field.name)

            if added_to_df1 or added_to_df2:
                dbg(f"  Schema drift merged. Padded accumulator: {added_to_df1} | padded incoming: {added_to_df2}")

            # Reorder df2 columns to match df1 before unioning
            df2 = df2.select(df1.columns)

            return df1.union(df2)

        dbg("Reducing DataFrames with schema-merge union...")
        df_all = reduce(union_with_schema_merge, dfs)
        dbg(f"Union complete. Final column count: {len(df_all.columns)}")

        # NOTE: .count() forces a full read of every parquet file — expensive.
        dbg("Counting rows (forces full scan)...")
        _count_start = time.time()
        total_rows = df_all.count()
        dbg(f"Row count = {total_rows} (took {time.time() - _count_start:.2f}s)")

        print(f"  Total rows   : {total_rows}")
        print(f"  Total columns: {df_all.schema.fieldNames()}")
        if DEBUG:
            print("  Schema:")
            df_all.printSchema()

        # --- 4. Write as a new delta table ---
        print("\n[4/4] Writing recovered delta table...")

        dbg(f"Ensuring schema exists: {pTargetSchema}")
        spark.sql(f"CREATE SCHEMA IF NOT EXISTS {pTargetSchema}")

        dbg(f"Writing delta to {TARGET_PATH} (mode=overwrite, mergeSchema=true)...")
        _write_start = time.time()
        (
            df_all.write
            .format("delta")
            .mode("overwrite")   # safe here — we confirmed table doesn't exist above
            .option("mergeSchema", "true")
            .save(TARGET_PATH)
        )
        dbg(f"Delta write complete (took {time.time() - _write_start:.2f}s)")

        dbg(f"Registering table in catalog: {pTargetSchema}.{pTargetTable}")
        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS {pTargetSchema}.`{pTargetTable}`
            USING DELTA
            LOCATION '{TARGET_PATH}'
        """)

        # Force a Metadata Refresh / force the SQL endpoint to sync the specific table
        query = f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`"
        dbg(f"Refreshing table metadata: {query}")
        spark.sql(query)

        print("\n" + "=" * 60)
        print("Recovery complete.")
        print(f"  Target table : {pTargetSchema}.{pTargetTable}")
        print(f"  Rows written : {total_rows}")
        print(f"  Elapsed      : {time.time() - _run_start:.2f}s")
        print("=" * 60)

        # --- 5. Exit SUCCESS
        # --- SET FLAG INSTEAD OF EXITING ---
        should_exit_success = True
        exit_message = f"SUCCESS: {total_rows} rows recovered"

    else:
        print(f"No parquet files found under {STAGING_ROOT_PATH}. Cannot recover.")
        dbg("No parquet files — nothing to do.")
        should_exit_success = True
        exit_message = "SUCCESS: No files to recover"

except Exception as e:
    # Emit the full traceback so pipeline failures are diagnosable.
    tb = traceback.format_exc()
    print("=" * 60)
    print("RECOVERY FAILED")
    print(tb)
    print("=" * 60)
    dbg(f"Exiting with FAILURE after {time.time() - _run_start:.2f}s")
    mssparkutils.notebook.exit(f"FAILURE: {str(e)}")

if should_exit_success:
    dbg(f"Exiting with success after {time.time() - _run_start:.2f}s: {exit_message}")
    mssparkutils.notebook.exit(exit_message)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
