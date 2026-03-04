# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "3231059f-0365-4fa8-81bc-a7ed8c6ad211",
# META       "default_lakehouse_name": "lh_SilverLayer",
# META       "default_lakehouse_workspace_id": "29f8113f-2a90-401e-a4f7-d6121b481419",
# META       "known_lakehouses": [
# META         {
# META           "id": "3231059f-0365-4fa8-81bc-a7ed8c6ad211"
# META         }
# META       ]
# META     }
# META   }
# META }

# PARAMETERS CELL ********************

# Parameters 
# Type here in the cell editor to add code!
pTargetSchema       = 'Kantata'
pBronzeTableShortcut = "BronzeKantata.BusinessUnit"
pSilverTableName    = "Kantata.HISTORY_BusinessUnit"
pWatermarkColumnName  = "SystemModstamp"
pWatermarkColumnValue = "2000-01-01 00:00:00"
pBronzeDataLoadWatermarkColumn = "_crda_BronzeLoadDateTime"
pBronzeDataLoadWatermarkValue  = "2000-01-01 00:00:00"
pPrimaryKeysJson    = '["Id"]'
pHashColumnsJson    = '["Budget_Code__c","CreatedDate","CurrencyIsoCode","isActive__c","isDefault__c","IsDeleted","KimbleOne__AllowanceScheme__c","KimbleOne__BusinessUnit__c","KimbleOne__BusinessUnitGroup__c","KimbleOne__Calendar__c","KimbleOne__CreditNoteFooter__c","KimbleOne__ExpenseItemExchangeRateTolerancePct__c","KimbleOne__ExpenseItemSubmissionDays__c","KimbleOne__ExpensesTaxCodeRule__c","KimbleOne__InternalAccount__c","KimbleOne__InvoiceFooter__c","KimbleOne__InvoicePaymentTermDays__c","KimbleOne__InvoiceTaxCodeNumber__c","KimbleOne__InvoicingAddress__c","KimbleOne__InvoicingBusinessUnitName__c","KimbleOne__InvoicingCity__c","KimbleOne__InvoicingCountry__c","KimbleOne__InvoicingCurrencyIsoCode__c","KimbleOne__InvoicingName__c","KimbleOne__InvoicingPostalCode__c","KimbleOne__InvoicingState__c","KimbleOne__InvoicingStreet__c","KimbleOne__InvoicingStreetName__c","KimbleOne__IsActive__c","KimbleOne__IsOperatingEntity__c","KimbleOne__IsPrimaryOrganisationalEntity__c","KimbleOne__IsSecondaryOrganisationalEntity__c","KimbleOne__IsTradingEntity__c","KimbleOne__LogoDocumentName__c","KimbleOne__TaxCode__c","KimbleOne__TaxCodeReference__c","KimbleOne__TimePattern__c","KimbleOne__TimePatternRule__c","KimbleOne__TimePatternVariant__c","LastReferencedDate","Name","OwnerId","Sage200CostCentreCode__c","Sage200DepartmentCode__c","SageDepartmentCode__c"]'
pTransformationsJson= '{"BusinessUnitName": "Name"}'
pExecutionId    = 1073
pProcessId      = 10


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC /* sandbox testing
# MAGIC drop table if exists Kantata.HISTORY_Business
# MAGIC */

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark",
# META   "frozen": true,
# META   "editable": false
# META }

# CELL ********************

import json
from datetime import datetime, timedelta
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import *
from delta.tables import DeltaTable

# --- 1. Parameter Initialization ---
# These are defined in the Fabric Notebook Parameter Cell
should_exit_success = False
try:
    # Parsing/transforming parameters from parameter cell that need it
    pk_list = json.loads(pPrimaryKeysJson)
    hash_cols = json.loads(pHashColumnsJson)
    transformations = json.loads(pTransformationsJson)
    exec_id = int(pExecutionId)
    proc_id = int(pProcessId)
    # Parsing/transforming Parameters
    
    TargetTable  = pSilverTableName.replace(".", "/")
    TARGET_PATH  = f"Tables/{TargetTable}"

    print("=" * 60)
    print("Load Silver from Bronze")
    print(f"  pBronzeTableShortcut : {pBronzeTableShortcut}")
    print(f"  pSilverTableName : {pSilverTableName}")
    print(f"  TARGET_PATH : {TARGET_PATH}")
    print("=" * 60)


    spark.sql(f"CREATE SCHEMA IF NOT EXISTS {pTargetSchema}")
    
    # --- 2. Extract & Deduplicate Bronze Data ---
    # Filter by Load Watermark (File creation time)
    df_bronze = spark.read.table(pBronzeTableShortcut) \
        .filter(F.col(pBronzeDataLoadWatermarkColumn) > pBronzeDataLoadWatermarkValue)

    if not df_bronze.isEmpty():

        print(f"  Rows   : {df_bronze.count()}")
        # print(f"  Columns: {df_bronze.schema.fieldNames()}")

        # Deduplicate within the batch: Keep latest SystemModstamp per PK
        window_spec = Window.partitionBy(*pk_list).orderBy(F.col(pWatermarkColumnName).desc())
        df_deduped = df_bronze.withColumn("rn", F.row_number().over(window_spec)) \
            .filter("rn = 1").drop("rn")
        print(f"  Rows after dedupe   : {df_deduped.count()}")

        # --- 3. Dynamic Transformations & Cleansing ---
        # Apply logic from TransformationsJson (e.g., {"new_col": "col_a + col_b", "clean_name": "upper(name)"})
        for col_name, expr in transformations.items():
            df_deduped = df_deduped.withColumn(col_name, F.expr(expr))

        # --- 4. Prepare Staging DataFrame for SCD2 ---
        # Add _crda_RowHash and Metadata columns
        df_staged = df_deduped.withColumn("_crda_RowHash", F.sha2(F.concat_ws("||", *hash_cols), 256)) \
            .withColumn("ActiveFromDateTime", F.col(pWatermarkColumnName)) \
            .withColumn("ActiveToDateTime", F.to_timestamp(F.lit("9999-12-31 23:59:59"))) \
            .withColumn("isDeleted", F.lit(False)) \
            .withColumn("_crda_SilverLoadDateTime", F.current_timestamp()) \
            .withColumn("_crda_CreatedExecutionId", F.lit(exec_id).cast("int")) \
            .withColumn("_crda_UpdatedExecutionId", F.lit(exec_id).cast("int"))

        # Calculated column for isCurrent
        df_staged = df_staged.withColumn("isCurrent", 
            F.when(F.col("ActiveToDateTime") == "9999-12-31 23:59:59", True).otherwise(False))

        # --- 5. Upsert Logic (Merge) ---
        if not spark.catalog.tableExists(pSilverTableName):
            print("=" * 60)
            print(f"  TargetTable : {pSilverTableName} : doesn't exist, so creating first time now ")
            print("=" * 60)
            # Initial Load
            (
                df_staged.write
                .format("delta")
                .save(TARGET_PATH)
            )
            print(f"TargetTable created {pSilverTableName}")

            # Register the table in the metastore preserving case, if it doesn't exist yet
            # spark.sql(f"""
            #    CREATE TABLE IF NOT EXISTS `{pSilverTableName}`
            #    USING DELTA
            #    LOCATION '{TARGET_PATH}'
            #""")
            # print(f"register")

        else:
            # SCD2 Merge Logic
            silverTable = DeltaTable.forName(spark, pSilverTableName)
            print(f"silverTable object initialized")
            
            # Identify records that need to be updated (PK match but Hash differs)
            # We perform a "Merge" where we update existing records to expire them
            # And insert new records. 
            # Note: True SCD2 usually requires a union for the 'Update + Insert' pattern
            
            join_condition = " AND ".join([f"target.{c} = source.{c}" for c in pk_list])
            
            # 1. Expire existing records
            # We execute and capture metrics in one go
            (
                silverTable.alias("target")
                .merge(
                    source = df_staged.alias("source"),
                    condition = f"{join_condition} AND target.isCurrent = true AND target._crda_RowHash <> source._crda_RowHash"
                )
                .whenMatchedUpdate(set = {
                    "ActiveToDateTime": F.expr("source.ActiveFromDateTime - INTERVAL 3 MILLISECONDS"),
                    "isCurrent": F.lit(False),
                    "_crda_UpdatedExecutionId": F.lit(exec_id)
                })
                .execute()
            )

            # 2. Insert new records
            # Only insert if the record is brand new or the hash has changed
            df_to_insert = df_staged.alias("source").join(
                spark.read.table(pSilverTableName).alias("target"),
                F.expr(f"{join_condition} AND target.isCurrent = true"),
                "left_outer"
            ).filter("target._crda_RowHash IS NULL OR source._crda_RowHash <> target._crda_RowHash") \
            .select("source.*")

            if not df_to_insert.isEmpty():
                print(f"Rows to insert : {df_to_insert.count()}")
                (
                    df_to_insert.write
                    .format("delta")
                    .mode("append")
                    .option("mergeSchema", "true")
                    .save(TARGET_PATH)
                )
                print(f"new inserts")
            else:
                print(f"nothing to insert")
        
        # Exit SUCCESS
        should_exit_success = True

    else:
        print("No new data found. Preparing to exit.")
        should_exit_success = True

except Exception as e:
    print(f"FAILURE: {str(e)}")
    mssparkutils.notebook.exit(f"FAILURE: {str(e)}")

if should_exit_success:
    mssparkutils.notebook.exit("SUCCESS")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
