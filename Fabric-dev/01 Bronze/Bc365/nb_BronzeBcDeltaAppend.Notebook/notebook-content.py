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
# Schema-Drift-Safe Delta Append
# Bronze Lakehouse | Parameterised
# ============================================================

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
# Notebook is attached to the Bronze lakehouse so we use
# the default lakehouse path via the well-known OneLake URI.
# ============================================================

# Build the full parquet source path
SRC_BC_PARQUET_PATH = f"Files/{pDeltaLakeFolder}/{pParquetFile}"

# Build the target delta table path (Tables/ is the managed Delta area)
TGT_BC_PATH  = f"Tables/{pTargetSchema}/{pTargetTable}"
SRC_BC_FILE_NAME = f"{pDeltaLakeFolder}/{pParquetFile}"

# Active Ids related
TGT_IDS_TBL     = pTargetTable + "_Id"
ACTIVE_IDS_SRC_BC_FILE_NAME= f"Files/{pSourceActiveIdsParquetFile}"
TGT_BC_IDs_PATH	=f"Tables/{pTargetSchema}/{TGT_IDS_TBL}"
TGT_BC_IDS_SQL_TABLE    = pTargetSchema + "." + TGT_IDS_TBL

CONTROL_COLUMN = "__merge_action"

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

        renamed_cols.append(
            col(f"`{c}`").alias(new_name)
        )

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

def align_to_existing_delta(df_new, TGT_BC_PATH):
    """
    Aligns incoming DataFrame to the existing Delta table schema.
    Fails fast if target columns are missing from source, because otherwise
    the notebook would write NULLs for those columns.
    # Active Ids related
    """

    existing_schema = spark.read.format("delta").load(TGT_BC_PATH).schema

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

    # Keep target column order first, then append genuinely new columns
    ordered_cols = target_cols + [c for c in source_cols if c not in target_set]

    df_new = df_new.select(*ordered_cols)

    return df_new

# ============================================================
# HELPER: parse key columns
# Active Ids related
# ============================================================

def parse_key_columns_from_pipeline_param(value):
    """Expected input from Fabric pipeline:

    ["BcCompanyId,id"]

    Also tolerates:
        BcCompanyId,id
        '["BcCompanyId,id"]'
        ["BcCompanyId", "id"]

    Output:
        ["BcCompanyId", "id"]
    """

    if value is None:
        raise Exception("pKeyColumns parameter is None.")

    # If Fabric passes this as a Python/list object, flatten it first.
    if isinstance(value, list):
        raw_value = ",".join([str(v) for v in value])
    else:
        raw_value = str(value)

    raw_value = (
        raw_value.strip()
        .replace("[", "")
        .replace("]", "")
        .replace('"', "")
        .replace("'", "")
    )

    key_columns = [
        c.strip().strip("`")
        for c in raw_value.split(",")
        if c.strip().strip("`")
    ]

    if not key_columns:
        raise Exception(
            f"pKeyColumns did not resolve to any valid columns. "
            f"Original value: {value}"
        )

    return key_columns

# ============================================================
# HELPER: validate required columns
# Active Ids related
# ============================================================

def validate_required_columns(df, required_columns, df_name):
    actual_cols = set(df.columns)

    missing_cols = [c for c in required_columns if c not in actual_cols]

    if missing_cols:
        raise Exception(
            f"{df_name} is missing required columns: {missing_cols}. "
            f"Actual columns: {df.columns}"
        )

# ============================================================
# HELPER: validate source key values are not null
# Active Ids related
# ============================================================

def validate_no_null_source_keys(df_source, key_columns):
    null_key_condition = reduce(
        lambda x, y: x | y, [col(f"`{c}`").isNull() for c in key_columns]
    )

    null_key_count = df_source.filter(null_key_condition).count()

    if null_key_count > 0:
        print("Rows with NULL key values:")
        display(df_source.filter(null_key_condition).limit(50))

        raise Exception(
            f"Source parquet contains {null_key_count} rows with NULL values "
            f"in primary key columns {key_columns}. Merge stopped."
        )

# ============================================================
# HELPER: build dynamic merge condition
# Active Ids related
# ============================================================

def build_merge_condition(key_columns):
    return " AND ".join([f"t.`{c}` = s.`{c}`" for c in key_columns])

# ============================================================
# HELPER: build dynamic insert values
# Active Ids related
# ============================================================

def build_insert_values(data_columns):
    return {c: f"s.`{c}`" for c in data_columns}



# ============================================================
# MAIN
# ============================================================

final_output = None

try:
    # Active Ids related
    KEY_COLUMNS = parse_key_columns_from_pipeline_param(pKeyColumns)

    print("=" * 60)
    print("Schema-drift-safe delta append")
    print(f"  Source : {SRC_BC_PARQUET_PATH}")
    print(f"  Target : {pTargetSchema}.{pTargetTable}")
    print("=" * 60)

    # Active Ids related
    print("Bronze Delta full-sync upsert")
    print(f"  Source path : {ACTIVE_IDS_SRC_BC_FILE_NAME}")
    print(f"  Target path : {TGT_BC_IDs_PATH}")
    print(f"  Target tbl  : {TGT_BC_IDS_SQL_TABLE}")
    print(f"  Key columns : {KEY_COLUMNS}")
    print("=" * 60)

    # Active Ids related
    # ------------------------------------------------------------
    # 1. Read incoming Parquet
    # ------------------------------------------------------------
    print("\n[1/6] Reading source parquet...")

    df_source_raw = spark.read.parquet(ACTIVE_IDS_SRC_BC_FILE_NAME)

    source_raw_count = df_source_raw.count()

    print(f"  Source rows raw     : {source_raw_count}")
    print(f"  Source columns raw  : {df_source_raw.columns}")

    df_source_raw = clean_bc_columns(df_source_raw)

    # Data columns are derived dynamically from the source parquet.
    # This keeps the notebook reusable across different BC entities.
    DATA_COLUMNS = df_source_raw.columns
    print(f"  Data columns derived: {DATA_COLUMNS}")

    # Ensure all key columns exist in the source.
    validate_required_columns(df_source_raw, KEY_COLUMNS, "Source parquet")

    # Keep all source columns in source order.
    # Backticks protect against unusual column names.
    df_source = df_source_raw.select(
        *[col(f"`{c}`").alias(c) for c in DATA_COLUMNS]
    )

    source_count = df_source.count()

    print(f"  Source rows selected    : {source_count}")
    print(f"  Source columns selected : {df_source.columns}")

    print("\n  Source sample:")
    display(df_source.limit(20))

    # ------------------------------------------------------------
    # 2. Check empty source
    # ------------------------------------------------------------

    print("\n[2/6] Checking source row count...")

    if source_count == 0:
        raise Exception(
            "Source parquet contains zero rows. Full-sync delete was not executed "
            "because an empty source would delete all target rows."
        )

    # ------------------------------------------------------------
    # 3. Ensure schema exists if pTargetTable is schema-qualified
    # ------------------------------------------------------------
    print("\n[3/6] Ensuring target schema exists...")

    if {pTargetSchema} is not None:
        print(f"  Ensuring schema exists: {pTargetSchema}")
        spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{pTargetSchema}`")


    target_exists = DeltaTable.isDeltaTable(spark, TGT_BC_IDs_PATH)

    if not target_exists:
        print("  Target Delta table does not exist. Creating from source...")

        (
            df_source.write.format("delta")
            .mode("overwrite")
            .option("overwriteSchema", "true")
            .save(TGT_BC_IDs_PATH)
        )

        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS {TGT_BC_IDS_SQL_TABLE}
            USING DELTA
            LOCATION '{TGT_BC_IDs_PATH}'
        """)

        spark.sql(f"REFRESH TABLE {TGT_BC_IDS_SQL_TABLE}")

        final_output = (
            f"SUCCESS: TargetCreated=1; "
            f"Inserted={source_count}; "
            f"Deleted=0; "
            f"Unchanged=0; "
            f"TargetRows={source_count}; "
            f"KeyColumns={','.join(KEY_COLUMNS)}"
        )

    else:
        print("  Target Delta table exists. Preparing full-sync merge...")

        delta_target = DeltaTable.forPath(spark, TGT_BC_IDs_PATH)
        df_target = delta_target.toDF()

        print(f"  Target columns : {df_target.columns}")

        # Ensure all key columns exist in the target.
        validate_required_columns(
            df_target, KEY_COLUMNS, "Target Delta table"
        )

        target_before_count = df_target.count()

        print(f"  Target rows before merge : {target_before_count}")

        # ------------------------------------------------------------
        # 4. Calculate metrics before merge
        # ------------------------------------------------------------

        print("\n[4/6] Calculating insert/delete/unchanged candidates...")

        df_source_keys = df_source.select(
            *[col(f"`{c}`").alias(c) for c in KEY_COLUMNS]
        ).dropDuplicates()

        df_target_keys = df_target.select(
            *[col(f"`{c}`").alias(c) for c in KEY_COLUMNS]
        ).dropDuplicates()

        df_insert_candidates = df_source_keys.join(
            df_target_keys, KEY_COLUMNS, "left_anti"
        )

        df_delete_candidates = df_target_keys.join(
            df_source_keys, KEY_COLUMNS, "left_anti"
        )

        df_unchanged_candidates = df_source_keys.join(
            df_target_keys, KEY_COLUMNS, "inner"
        )

        insert_count = df_insert_candidates.count()
        delete_count = df_delete_candidates.count()
        unchanged_count = df_unchanged_candidates.count()

        print(f"  Insert candidates    : {insert_count}")
        print(f"  Delete candidates    : {delete_count}")
        print(f"  Existing/no-op keys  : {unchanged_count}")

        # ------------------------------------------------------------
        # 5. Build merge source
        # ------------------------------------------------------------

        print("\n[5/6] Building merge source...")

        # Source rows are used for insert attempts.
        # Matching target rows do nothing because there is no whenMatchedUpdate.
        df_merge_insert = df_source.withColumn(CONTROL_COLUMN, lit("I"))

        # Target-only keys are used for delete attempts.
        # Add the non-key source columns as NULL so the delete DataFrame
        # has the same shape as the insert DataFrame.
        df_merge_delete = df_delete_candidates

        source_schema = df_source.schema

        for c in DATA_COLUMNS:
            if c not in KEY_COLUMNS:
                df_merge_delete = df_merge_delete.withColumn(
                    c, lit(None).cast(source_schema[c].dataType)
                )

        df_merge_delete = df_merge_delete.select(
            *[col(f"`{c}`").alias(c) for c in DATA_COLUMNS]
        ).withColumn(CONTROL_COLUMN, lit("D"))

        df_merge = df_merge_insert.unionByName(df_merge_delete)

        merge_source_count = df_merge.count()

        print(f"  Merge source rows : {merge_source_count}")

        print("\n  Merge source sample:")
        display(df_merge.limit(20))

        # ------------------------------------------------------------
        # 6. Execute merge
        # ------------------------------------------------------------

        print("\n[6/6] Executing Delta merge...")

        merge_condition = build_merge_condition(KEY_COLUMNS)
        insert_values = build_insert_values(DATA_COLUMNS)

        print(f"  Merge condition : {merge_condition}")
        print(f"  Insert values   : {insert_values}")

        (
            delta_target.alias("t")
            .merge(df_merge.alias("s"), merge_condition)
            .whenMatchedDelete(condition=f"s.`{CONTROL_COLUMN}` = 'D'")
            .whenNotMatchedInsert(
                condition=f"s.`{CONTROL_COLUMN}` = 'I'", values=insert_values
            )
            .execute()
        )

        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS {TGT_BC_IDS_SQL_TABLE}
            USING DELTA
            LOCATION '{TGT_BC_IDs_PATH}'
        """)

        spark.sql(f"REFRESH TABLE {TGT_BC_IDS_SQL_TABLE}")

        target_after_count = (
            spark.read.format("delta").load(TGT_BC_IDs_PATH).count()
        )

        print("\n" + "=" * 60)
        print("Full-sync upsert complete.")
        print(f"  Target table       : {TGT_BC_IDS_SQL_TABLE}")
        print(f"  Key columns        : {KEY_COLUMNS}")
        print(f"  Target rows before : {target_before_count}")
        print(f"  Inserted           : {insert_count}")
        print(f"  Deleted            : {delete_count}")
        print(f"  Existing/no-op     : {unchanged_count}")
        print(f"  Target rows after  : {target_after_count}")
        print("=" * 60)



    # ------------------------------------------------------------
    # 1. Read incoming Parquet
    # ------------------------------------------------------------

    print("\n[1/6] Reading source parquet...")

    df_new = spark.read.parquet(SRC_BC_PARQUET_PATH)

    df_new = (
        df_new
        .withColumn(
            "_crda_BronzeLoadDateTime",
            lit(pBronzeLoadDateTime).cast("timestamp")
        )
        .withColumn(
            "_crda_SourceExecutionId",
            lit(pSourceExecutionId).cast("int")
        )
        .withColumn(
            "BcCompanyName",
            lit(pBcCompanyName)
        )
        .withColumn(
            "BcCompanyId",
            lit(pBcCompanyId)
        )
        .withColumn(
            "_crda_SourceFileName",
            lit(SRC_BC_FILE_NAME)
        )
    )


    print(f"  Rows before cleaning    : {df_new.count()}")
    print(f"  Columns before cleaning : {df_new.schema.fieldNames()}")

    # ------------------------------------------------------------
    # 2. Clean BC source columns
    # ------------------------------------------------------------

    print("\n[2/6] Cleaning source columns...")

    df_new = clean_bc_columns(df_new)

    print(f"  Rows after cleaning     : {df_new.count()}")
    print(f"  Columns after cleaning  : {df_new.schema.fieldNames()}")

    print("\n  Cleaned source schema:")
    df_new.printSchema()

    # Optional but useful while troubleshooting
    print("\n  Sample source rows after cleaning:")
    display(df_new.limit(13))

    # ------------------------------------------------------------
    # 3. Check for empty source
    # ------------------------------------------------------------

    if df_new.isEmpty():
        print("\nNo new data found. Returning existing watermark.")
        final_output = str(pBronzeWatermarkValue)

    else:
        # ------------------------------------------------------------
        # 4. Ensure schema exists
        # ------------------------------------------------------------

        #spark.sql(f"DROP TABLE IF EXISTS `{pTargetSchema}`.`{pTargetTable}`")

        #mssparkutils.fs.rm(TGT_BC_PATH, recurse=True)

        #spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{pTargetSchema}`")

        #(
        #    df_new.write
        #    .format("delta")
        #    .mode("overwrite")
        #    .option("overwriteSchema", "true")
        #    .save(TGT_BC_PATH)
        #)

        #spark.sql(f"""
        #CREATE TABLE `{pTargetSchema}`.`{pTargetTable}`
        #USING DELTA
        #LOCATION '{TGT_BC_PATH}'
        #""")

        #spark.sql(f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`")

        print("\n[3/6] Ensuring target schema exists...")

        spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{pTargetSchema}`")

        # ------------------------------------------------------------
        # 5. Check existing Delta table and align schema
        # ------------------------------------------------------------

        print("\n[4/6] Checking target Delta table...")

        if DeltaTable.isDeltaTable(spark, TGT_BC_PATH):
            print("  Target table EXISTS - validating and aligning schema...")

            print("\n  Existing target schema:")
            spark.read.format("delta").load(TGT_BC_PATH).printSchema()

            df_new = align_to_existing_delta(df_new, TGT_BC_PATH)

        else:
            print("  Target table does NOT exist - will be created from incoming schema.")

        # ------------------------------------------------------------
        # 6. Append to Delta
        # ------------------------------------------------------------

        print("\n[5/6] Appending to Delta table...")

        (
            df_new.write
            .format("delta")
            .mode("append")
            .option("mergeSchema", "true")
            .save(TGT_BC_PATH)
        )

        # Register table in Lakehouse metastore if it does not already exist
        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS `{pTargetSchema}`.`{pTargetTable}`
            USING DELTA
            LOCATION '{TGT_BC_PATH}'
        """)

        # Refresh table metadata
        spark.sql(f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`")

        print("\n" + "=" * 60)
        print("Append complete.")
        print(f"  Target table : {pTargetSchema}.{pTargetTable}")
        print(f"  Rows written : {df_new.count()}")
        print("=" * 60)

        # ------------------------------------------------------------
        # 7. Calculate watermark
        # ------------------------------------------------------------

        print("\n[6/6] Calculating watermark for pipeline...")

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
    # Exception handling for Fabric pipeline
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
