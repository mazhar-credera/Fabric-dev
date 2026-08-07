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
pTargetSchema = "BC"
pTargetTable = "custLedgerEntries"
pParquetFile = "05-115730.parquet"
pDeltaLakeFolder = "raw/bronze/BC/custLedgerEntries/2026/07"
pWatermarkColumnName = "lastModifiedDateTime"
pBronzeWatermarkValue= "0001-01-01"
pBcCompanyName= "Credera Ltd"
pBcCompanyId= "3abc695f-7d28-ec11-8f45-0022481b4f2e"
pBronzeLoadDateTime= "2026-07-15 10:00:00"
pSourceExecutionId= "1073"
pSourceActiveIdsParquetFile= "tmp/bronze/Bc/custLedgerEntries/CrederaLtdActiveIds.parquet"
pKeyColumns = '["BcCompanyId,id"]'


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
# Schema-Drift-Safe Pipeline: Main Append + Active IDs Upsert
# Bronze Lakehouse | Parameterised
# ============================================================

import json
import time
import random
from functools import reduce
from pyspark.sql.functions import col, count as spark_count, lit
from delta.tables import DeltaTable

# Handle Reading
spark.conf.set("spark.sql.parquet.int96RebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")

# Handle Writing
spark.conf.set("spark.sql.parquet.int96RebaseModeInWrite", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

# ============================================================
# DERIVED PATHS
# ============================================================

# 1. Main Table Paths
SRC_BC_PARQUET_PATH = f"Files/{pDeltaLakeFolder}/{pParquetFile}"
TGT_BC_PATH         = f"Tables/{pTargetSchema}/{pTargetTable}"
SRC_BC_FILE_NAME    = f"{pDeltaLakeFolder}/{pParquetFile}"

# 2. Active IDs Table Paths
SRC_ACTIVE_IDS_PATH   = f"Files/{pSourceActiveIdsParquetFile}" if not pSourceActiveIdsParquetFile.startswith("Files/") else pSourceActiveIdsParquetFile
ACTIVE_IDS_TABLE_NAME = f"{pTargetTable}_Id"
TGT_ACTIVE_IDS_PATH   = f"Tables/{pTargetSchema}/{ACTIVE_IDS_TABLE_NAME}"

# Dynamic list of Delta concurrency errors to trigger retry backoff
RETRYABLE_ERRORS = [
    "DELTA_CONCURRENT_APPEND",
    "DELTA_PROTOCOL_CHANGED",
    "ConcurrentAppendException",
    "ConcurrentTransactionException",
    "DELTA_CONCURRENT_MODIFICATION"
]

# ============================================================
# HELPER: clean Business Central column names
# ============================================================

def clean_bc_columns(df):
    """
    Removes leading 'value.' prefix from columns and drops OData metadata columns.
    This is done in memory only. The raw Parquet file is left unchanged.
    """
    print("  Start clean_bc_columns")
    print(df.columns)

    renamed_cols = []
    for c in df.columns:
        new_name = c
        if c.startswith("value."):
            new_name = c[6:]
        renamed_cols.append(col(f"`{c}`").alias(new_name))

    df = df.select(*renamed_cols)

    unwanted_cols = [
        "@odata.context",
        "@odata.etag",
        "@odata.nextLink",
        "odata.context",
        "odata.etag"
    ]

    cols_to_drop = [c for c in unwanted_cols if c in df.columns]

    if cols_to_drop:
        df = df.drop(*cols_to_drop)

    print("  End clean_bc_columns")
    return df

# ============================================================
# HELPER: align incoming columns to existing Delta target
# ============================================================

def align_to_existing_delta(df_new, tgt_delta_path):
    """
    Aligns incoming DataFrame to the existing Delta table schema.
    """
    existing_schema = spark.read.format("delta").load(tgt_delta_path).schema

    target_cols = existing_schema.fieldNames()
    source_cols = df_new.schema.fieldNames()

    target_set = set(target_cols)
    source_set = set(source_cols)

    new_cols = sorted(source_set - target_set)
    missing_in_source = sorted(target_set - source_set)

    print("\n[SCHEMA CHECK]")
    print(f"  New columns in source               : {new_cols if new_cols else 'None'}")
    print(f"  Target columns missing from source  : {missing_in_source if missing_in_source else 'None'}")

    if missing_in_source:
        for field in existing_schema.fields:
            if field.name not in source_set:
                print(f"  [COL REMOVED] Column '{field.name}' missing from source - writing nulls")
                df_new = df_new.withColumn(field.name, lit(None).cast(field.dataType))

    # Cast matching columns to existing Delta types
    for field in existing_schema.fields:
        if field.name in source_set:
            incoming_type = df_new.schema[field.name].dataType

            if incoming_type != field.dataType:
                print(
                    f"  [TYPE DRIFT] Column '{field.name}': "
                    f"{incoming_type} -> casting to {field.dataType}"
                )
                df_new = df_new.withColumn(
                    field.name,
                    col(field.name).cast(field.dataType)
                )

    ordered_cols = target_cols + [c for c in source_cols if c not in target_set]
    df_new = df_new.select(*ordered_cols)

    return df_new

# ============================================================
# MAIN
# ============================================================

final_output = None

try:
    print("=" * 60)
    print("Schema-drift-safe pipeline starting...")
    print(f"  Main Source     : {SRC_BC_PARQUET_PATH}")
    print(f"  Main Target     : {pTargetSchema}.{pTargetTable}")
    print(f"  Active IDs Source: {SRC_ACTIVE_IDS_PATH}")
    print(f"  Active IDs Target: {pTargetSchema}.{ACTIVE_IDS_TABLE_NAME}")
    print("=" * 60)

    # ------------------------------------------------------------
    # PART 1: MAIN ENTITY DELTA APPEND (WITH RETRY LOGIC)
    # ------------------------------------------------------------

    print("\n[PART 1] Reading main entity source parquet...")
    df_main = spark.read.parquet(SRC_BC_PARQUET_PATH)

    df_main = (
        df_main
        .withColumn("_crda_BronzeLoadDateTime", lit(pBronzeLoadDateTime).cast("timestamp"))
        .withColumn("_crda_SourceExecutionId", lit(pSourceExecutionId).cast("int"))
        .withColumn("BcCompanyName", lit(pBcCompanyName))
        .withColumn("BcCompanyId", lit(pBcCompanyId))
        .withColumn("_crda_SourceFileName", lit(SRC_BC_FILE_NAME))
    )

    print(f"  Main rows before cleaning    : {df_main.count()}")
    df_main = clean_bc_columns(df_main)

    if df_main.isEmpty():
        print("\nNo main data found. Returning existing watermark.")
        final_output = str(pBronzeWatermarkValue)
    else:
        print("\nEnsuring target schema exists...")
        spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{pTargetSchema}`")

        print("\nProcessing Main Delta Table append...")
        if DeltaTable.isDeltaTable(spark, TGT_BC_PATH):
            df_main = align_to_existing_delta(df_main, TGT_BC_PATH)

        # Retry logic for optimistic concurrency during append
        max_retries = 5
        base_delay_seconds = 3

        for attempt in range(1, max_retries + 1):
            try:
                (
                    df_main.write
                    .format("delta")
                    .partitionBy("BcCompanyId")
                    .mode("append")
                    .option("mergeSchema", "true")
                    .save(TGT_BC_PATH)
                )
                print(f"  Main Table Append succeeded on attempt {attempt}.")
                break

            except Exception as append_err:
                error_str = str(append_err)
                is_retryable = any(err in error_str for err in RETRYABLE_ERRORS)

                if is_retryable and attempt < max_retries:
                    jitter = random.uniform(0.5, 1.5)
                    wait_time = round((base_delay_seconds ** attempt) + jitter, 2)
                    print(f"  [Attempt {attempt}/{max_retries}] Main Table Append Concurrency collision. Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    raise append_err

        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS `{pTargetSchema}`.`{pTargetTable}`
            USING DELTA
            LOCATION '{TGT_BC_PATH}'
        """)
        spark.sql(f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`")

        print(f"Main Table Append Complete: {pTargetSchema}.{pTargetTable}")

    # ------------------------------------------------------------
    # PART 2: ACTIVE IDS DELTA UPSERT (MERGE + SCOPED DELETE WITH RETRY)
    # ------------------------------------------------------------

    print("\n[PART 2] Processing Active IDs Delta Upsert...")
    
    # Read Active IDs source parquet
    df_active = spark.read.parquet(SRC_ACTIVE_IDS_PATH)

    df_active = (
        df_active
        .withColumn("_crda_BronzeLoadDateTime", lit(pBronzeLoadDateTime).cast("timestamp"))
        .withColumn("_crda_SourceExecutionId", lit(pSourceExecutionId).cast("int"))
        .withColumn("BcCompanyName", lit(pBcCompanyName))
        .withColumn("BcCompanyId", lit(pBcCompanyId))
        .withColumn("_crda_SourceFileName", lit(pSourceActiveIdsParquetFile))
    )

    df_active = clean_bc_columns(df_active)

    if not df_active.isEmpty():
        if DeltaTable.isDeltaTable(spark, TGT_ACTIVE_IDS_PATH):
            print(f"  Target active table EXISTS ({TGT_ACTIVE_IDS_PATH}) - preparing Merge...")

            df_active = align_to_existing_delta(df_active, TGT_ACTIVE_IDS_PATH)

            # Parse key columns e.g. ["BcCompanyId,id"]
            raw_keys = json.loads(pKeyColumns) if isinstance(pKeyColumns, str) and pKeyColumns.startswith("[") else [pKeyColumns]
            key_cols = []
            for item in raw_keys:
                key_cols.extend([col.strip() for col in item.split(",") if col.strip()])

            merge_condition = " AND ".join([f"target.{col} = source.{col}" for col in key_cols])
            print(f"  Active IDs Merge Condition : {merge_condition}")

            # Scope delete condition to company IDs present in this active IDs snapshot
            distinct_companies = [row["BcCompanyId"] for row in df_active.select("BcCompanyId").distinct().collect()]
            if distinct_companies:
                formatted_ids = ", ".join([f"'{c}'" if isinstance(c, str) else str(c) for c in distinct_companies])
                delete_condition = f"target.BcCompanyId IN ({formatted_ids})"
            else:
                delete_condition = "1 = 0"

            print(f"  Active IDs Delete Condition: {delete_condition}")

            # Retry logic for optimistic concurrency during merge
            max_retries = 5
            base_delay_seconds = 3

            for attempt in range(1, max_retries + 1):
                try:
                    target_active_delta = DeltaTable.forPath(spark, TGT_ACTIVE_IDS_PATH)

                    (
                        target_active_delta.alias("target")
                        .merge(
                            df_active.alias("source"),
                            merge_condition
                        )
                        # Rule 1: Key exists in Target -> DO NOTHING
                        # Rule 2: Key does NOT exist in Target -> INSERT
                        .whenNotMatchedInsertAll()
                        # Rule 3: Key in Target does NOT exist in Source -> DELETE
                        .whenNotMatchedBySourceDelete(condition=delete_condition)
                        .execute()
                    )

                    print(f"  Active IDs Merge succeeded on attempt {attempt}.")
                    break

                except Exception as merge_err:
                    error_str = str(merge_err)
                    is_retryable = any(err in error_str for err in RETRYABLE_ERRORS)

                    if is_retryable and attempt < max_retries:
                        jitter = random.uniform(0.5, 1.5)
                        wait_time = round((base_delay_seconds ** attempt) + jitter, 2)
                        print(f"  [Attempt {attempt}/{max_retries}] Active IDs Concurrency collision. Retrying in {wait_time}s...")
                        time.sleep(wait_time)
                    else:
                        raise merge_err

        else:
            print(f"  Target active table does NOT exist - creating initial table at {TGT_ACTIVE_IDS_PATH}...")
            (
                df_active.write
                .format("delta")
                .partitionBy("BcCompanyId")
                .mode("append")
                .option("mergeSchema", "true")
                .save(TGT_ACTIVE_IDS_PATH)
            )

        # Register and refresh metastore table
        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS `{pTargetSchema}`.`{ACTIVE_IDS_TABLE_NAME}`
            USING DELTA
            LOCATION '{TGT_ACTIVE_IDS_PATH}'
        """)
        spark.sql(f"REFRESH TABLE `{pTargetSchema}`.`{ACTIVE_IDS_TABLE_NAME}`")

        print(f"Active IDs Upsert Complete: {pTargetSchema}.{ACTIVE_IDS_TABLE_NAME}")

    # ------------------------------------------------------------
    # PART 3: WATERMARK CALCULATION
    # ------------------------------------------------------------

    print("\n[PART 3] Calculating watermark for pipeline...")

    watermark_df = spark.sql(f"""
        SELECT COALESCE(
            MAX(`{pWatermarkColumnName}`),
            '{pBronzeWatermarkValue}'
        ) AS BronzeWatermarkValue
        FROM `{pTargetSchema}`.`{pTargetTable}`
    """)

    final_output = str(watermark_df.collect()[0][0])
    print(f"  Watermark identified: {final_output}")

except Exception as e:
    # ------------------------------------------------------------
    # Exception handling for Fabric pipeline (UNCHANGED)
    # ------------------------------------------------------------

    error_msg = f"FAILURE: {str(e)}"

    print("\n" + "=" * 60)
    print("Notebook failed.")
    print(error_msg)
    print("=" * 60)

    mssparkutils.notebook.exit(error_msg)

# ============================================================
# FINAL EXIT
# ============================================================

if final_output is not None:
    mssparkutils.notebook.exit(final_output)
else:
    mssparkutils.notebook.exit("FAILURE: Notebook completed without producing a watermark.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }
