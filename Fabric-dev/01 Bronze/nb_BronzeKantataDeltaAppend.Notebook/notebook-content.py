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

from pyspark.sql.functions import col, lit, max as spark_max
from delta.tables import DeltaTable

# ============================================================
# PARQUET DATE/TIME COMPATIBILITY
# ============================================================

spark.conf.set("spark.sql.parquet.int96RebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")

spark.conf.set("spark.sql.parquet.int96RebaseModeInWrite", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

# ============================================================
# DERIVED PATHS
# ============================================================

PARQUET_PATH = f"Files/{pDeltaLakeFolder}/{pParquetFile}"
TARGET_PATH = f"Tables/{pTargetSchema}/{pTargetTable}"

# ============================================================
# HELPER: ALIGN TO EXISTING DELTA SCHEMA
# ============================================================

def align_to_existing_delta(df_new, existing_schema):

    target_cols = existing_schema.fieldNames()
    source_cols = df_new.schema.fieldNames()

    target_set = set(target_cols)
    source_set = set(source_cols)

    new_cols = sorted(source_set - target_set)
    missing_in_source = sorted(target_set - source_set)

    print("\n[SCHEMA CHECK]")
    print(f"  New columns in source              : {new_cols if new_cols else 'None'}")
    print(f"  Missing from source                : {missing_in_source if missing_in_source else 'None'}")

    # --------------------------------------------------------
    # Add missing columns as NULL
    # --------------------------------------------------------

    for field in existing_schema.fields:

        if field.name not in source_set:

            print(
                f"  [COL REMOVED] '{field.name}' "
                f"missing from source - adding NULL column"
            )

            df_new = df_new.withColumn(
                field.name,
                lit(None).cast(field.dataType)
            )

    # --------------------------------------------------------
    # Type drift handling
    # --------------------------------------------------------

    for field in existing_schema.fields:

        if field.name in source_set:

            incoming_type = df_new.schema[field.name].dataType

            if incoming_type != field.dataType:

                print(
                    f"  [TYPE DRIFT] "
                    f"{field.name}: "
                    f"{incoming_type} -> {field.dataType}"
                )

                failed_casts = (
                    df_new
                    .filter(
                        col(field.name).isNotNull() &
                        col(field.name).cast(field.dataType).isNull()
                    )
                    .count()
                )

                if failed_casts > 0:

                    print(
                        f"  [WARNING] {failed_casts} values "
                        f"will become NULL during cast of "
                        f"{field.name}"
                    )

                df_new = df_new.withColumn(
                    field.name,
                    col(field.name).cast(field.dataType)
                )

    ordered_cols = target_cols + [
        c for c in source_cols
        if c not in target_set
    ]

    df_new = df_new.select(*ordered_cols)

    return df_new


# ============================================================
# MAIN
# ============================================================

final_output = None

try:

    print("=" * 80)
    print("SCHEMA-DRIFT-SAFE DELTA APPEND")
    print("=" * 80)

    print(f"Source parquet : {PARQUET_PATH}")
    print(f"Target table   : {pTargetSchema}.{pTargetTable}")
    print(f"Target path    : {TARGET_PATH}")

    # --------------------------------------------------------
    # 1. Read Source
    # --------------------------------------------------------

    print("\n[1/6] Reading source parquet")

    df_new = (
        spark.read
        .parquet(PARQUET_PATH)
        .cache()
    )

    row_count = df_new.count()

    print(f"  Row count          : {row_count}")
    print(f"  Column count       : {len(df_new.columns)}")
    print(f"  Partitions         : {df_new.rdd.getNumPartitions()}")

    print("\n  Column names:")
    print(df_new.columns)

    print("\n  Source schema:")
    df_new.printSchema()

    print("\n  Sample rows:")
    display(df_new.limit(10))

    # --------------------------------------------------------
    # 2. Empty Source Check
    # --------------------------------------------------------

    if row_count == 0:

        print("\nNo rows found.")

        final_output = str(pBronzeWatermarkValue)

    else:

        # ----------------------------------------------------
        # 3. Ensure Schema Exists
        # ----------------------------------------------------

        print("\n[3/6] Ensuring target schema exists")

        spark.sql(
            f"CREATE SCHEMA IF NOT EXISTS `{pTargetSchema}`"
        )

        # ----------------------------------------------------
        # 4. Delta Table Validation
        # ----------------------------------------------------

        print("\n[4/6] Validating target Delta table")

        if DeltaTable.isDeltaTable(spark, TARGET_PATH):

            print("  Delta table EXISTS")

            target_df = (
                spark.read
                .format("delta")
                .load(TARGET_PATH)
            )

            existing_schema = target_df.schema

            print("\n  Existing target schema:")
            target_df.printSchema()

            df_new = align_to_existing_delta(
                df_new,
                existing_schema
            )

        else:

            print(
                "  Delta table DOES NOT EXIST. "
                "Table will be created from incoming schema."
            )

        # ----------------------------------------------------
        # PRE-WRITE DEBUGGING
        # ----------------------------------------------------

        print("\n[PRE-WRITE VALIDATION]")

        print(f"  Rows to write      : {row_count}")
        print(f"  Columns to write   : {len(df_new.columns)}")
        print(f"  Target path        : {TARGET_PATH}")
        print(f"  Watermark column   : {pWatermarkColumnName}")

        # ----------------------------------------------------
        # 5. Append To Delta
        # ----------------------------------------------------

        print("\n[5/6] Appending to Delta")

        (
            df_new.write
            .format("delta")
            .mode("append")
            .option("mergeSchema", "true")
            .save(TARGET_PATH)
        )

        # ----------------------------------------------------
        # Register Table
        # ----------------------------------------------------

        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS `{pTargetSchema}`.`{pTargetTable}`
            USING DELTA
            LOCATION '{TARGET_PATH}'
        """)

        spark.sql(
            f"REFRESH TABLE `{pTargetSchema}`.`{pTargetTable}`"
        )

        print("\n" + "=" * 80)
        print("APPEND COMPLETE")
        print(f"Target table : {pTargetSchema}.{pTargetTable}")
        print(f"Rows written : {row_count}")
        print("=" * 80)

        # ----------------------------------------------------
        # 6. Watermark Calculation
        # ----------------------------------------------------

        print("\n[6/6] Calculating watermark")

        if pWatermarkColumnName in df_new.columns:

            batch_watermark = (
                df_new
                .agg(
                    spark_max(
                        col(pWatermarkColumnName)
                    ).alias("WatermarkValue")
                )
                .first()["WatermarkValue"]
            )

            if batch_watermark is not None:

                final_output = str(batch_watermark)

            else:

                final_output = str(pBronzeWatermarkValue)

        else:

            print(
                f"[WARNING] Watermark column "
                f"'{pWatermarkColumnName}' "
                f"not present in source dataset."
            )

            final_output = str(pBronzeWatermarkValue)

        print(f"  Watermark identified: {final_output}")

except Exception as e:

    # --------------------------------------------------------
    # Existing Exception Handling
    # --------------------------------------------------------

    error_msg = f"FAILURE: {str(e)}"

    print("\n" + "=" * 80)
    print("NOTEBOOK FAILED")
    print(error_msg)
    print("=" * 80)

    mssparkutils.notebook.exit(error_msg)

# ============================================================
# FINAL EXIT
# ============================================================

if final_output is not None:

    mssparkutils.notebook.exit(final_output)

else:

    mssparkutils.notebook.exit(
        "FAILURE: Notebook completed without producing a watermark."
    )

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }
