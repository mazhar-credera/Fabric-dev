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

from pyspark.sql.functions import col, lit
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
PARQUET_PATH = f"Files/{pDeltaLakeFolder}/{pParquetFile}"

# Build the target delta table path (Tables/ is the managed Delta area)
TARGET_PATH  = f"Tables/{pTargetSchema}/{pTargetTable}"

# ============================================================
# HELPER: align incoming columns to existing Delta target
# ============================================================

def align_to_existing_delta(df_new, target_path):
    """
    Aligns incoming DataFrame to the existing Delta table schema.
    Fails fast if target columns are missing from source, because otherwise
    the notebook would write NULLs for those columns.
    """

    existing_schema = spark.read.format("delta").load(target_path).schema

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
# MAIN
# ============================================================

final_output = None

try:
    print("=" * 60)
    print("Schema-drift-safe delta append")
    print(f"  Source : {PARQUET_PATH}")
    print(f"  Target : {pTargetSchema}.{pTargetTable}")
    print("=" * 60)

    # ------------------------------------------------------------
    # 1. Read incoming Parquet
    # ------------------------------------------------------------

    print("\n[1/6] Reading source parquet...")

    df_new = spark.read.parquet(PARQUET_PATH)

    print(f"  Rows before cleaning    : {df_new.count()}")
    print(f"  Columns before cleaning : {df_new.schema.fieldNames()}")

    # ------------------------------------------------------------
    # 2. Clean BC source columns
    # ------------------------------------------------------------

    print(f"  Rows after cleaning     : {df_new.count()}")
    print(f"  Columns after cleaning  : {df_new.schema.fieldNames()}")

    print("\n  Cleaned source schema:")
    df_new.printSchema()

    # Optional but useful while troubleshooting
    print("\n  Sample source rows after cleaning:")
    display(df_new.limit(13))

    # ------------------------------------------------------------
    # 2. Check for empty source
    # ------------------------------------------------------------

    if df_new.isEmpty():
        print("\nNo new data found. Returning existing watermark.")
        final_output = str(pBronzeWatermarkValue)

    else:
        # ------------------------------------------------------------
        # 3. Ensure schema exists
        # ------------------------------------------------------------

        print("\n[3/6] Ensuring target schema exists...")

        spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{pTargetSchema}`")

        # ------------------------------------------------------------
        # 4. Check existing Delta table and align schema
        # ------------------------------------------------------------

        print("\n[4/6] Checking target Delta table...")

        if DeltaTable.isDeltaTable(spark, TARGET_PATH):
            print("  Target table EXISTS - validating and aligning schema...")

            print("\n  Existing target schema:")
            spark.read.format("delta").load(TARGET_PATH).printSchema()

            df_new = align_to_existing_delta(df_new, TARGET_PATH)

        else:
            print("  Target table does NOT exist - will be created from incoming schema.")

        # ------------------------------------------------------------
        # 5. Append to Delta
        # ------------------------------------------------------------

        print("\n[5/6] Appending to Delta table...")

        (
            df_new.write
            .format("delta")
            .mode("append")
            .option("mergeSchema", "true")
            .save(TARGET_PATH)
        )

        # Register table in Lakehouse metastore if it does not already exist
        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS `{pTargetSchema}`.`{pTargetTable}`
            USING DELTA
            LOCATION '{TARGET_PATH}'
        """)

        # Refresh table metadata
        spark.sql(f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`")

        print("\n" + "=" * 60)
        print("Append complete.")
        print(f"  Target table : {pTargetSchema}.{pTargetTable}")
        print(f"  Rows written : {df_new.count()}")
        print("=" * 60)

        # ------------------------------------------------------------
        # 6. Calculate watermark
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
