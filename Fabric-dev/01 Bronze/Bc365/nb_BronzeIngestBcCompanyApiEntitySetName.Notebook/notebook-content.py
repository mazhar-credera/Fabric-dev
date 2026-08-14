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

# ============================================================
# Schema-Drift-Safe Pipeline + API Ingestion: Loop by Company
# Bronze Lakehouse | Fabric Entra ID Authentication
# ============================================================

# =============================================================================
# SECTION 1 – PARAMETERS
# All values are injected by the orchestrator (e.g. Data Factory / Fabric
# Pipeline). This cell must be tagged as a "parameter cell" in Fabric.
# Defaults below are illustrative only and should not be relied upon in production.
# =============================================================================
pBc365TenantId  = "pBc365TenantId"
pBc365UkEnv     = "Sandbox"
pOauth2Token    = "pOauth2Token"
pBcCompanyName  = "Omnicom"
pBcCompanyId    = "pBcCompanyId"
pCleanedCompanyName= "Omnicom"
pParentPipelineName= "pl_IngestBc365"
pSqlServer      = "pSqlServer"
pSqlDatabase    = "pSqlDatabase"


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# =============================================================================
# SECTION 1 – IMPORTS
# =============================================================================

import json
import time
import random
import struct
import requests
import pyodbc
import sempy.fabric as fabric
from datetime import datetime, timezone
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit
from delta.tables import DeltaTable
from notebookutils import mssparkutils
from pyspark.sql.types import LongType, IntegerType, DoubleType

# Handle Parquet Rebase Settings
spark.conf.set("spark.sql.parquet.int96RebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.int96RebaseModeInWrite", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")
# Increase maximum RPC message size for large driver-to-worker payloads
# spark.conf.set("spark.rpc.message.maxSize", "512")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }

# CELL ********************

# ============================================================
# SECTION 2 – CONSTANTS & CONFIGURATION
# ============================================================

# Environment & API Parameters
Bc365TenantId = pBc365TenantId
Bc365UkEnv = pBc365UkEnv
Oauth2Token = pOauth2Token

# Company Parameters
BcCompanyName = pBcCompanyName
BcCompanyId = pBcCompanyId
ParentPipelineName = pParentPipelineName
CleanedCompanyName = pCleanedCompanyName

# Fabric SQL Endpoint Parameters (No passwords required)
SqlServer = pSqlServer  # "your-fabric-server.database.windows.net"
SqlDatabase = pSqlDatabase  # "your_fabric_database_name"

# System Execution Variables
WORKSPACE_ID = fabric.get_notebook_workspace_id()
PIPELINE_RUN_ID = mssparkutils.env.getJobId()

print(f"Bc365TenantId : {Bc365TenantId}.")
print(f"Bc365UkEnv : {Bc365UkEnv}.")
print(f"BcCompanyName : {BcCompanyName}.")
print(f"BcCompanyId : {BcCompanyId}.")
print(f"ParentPipelineName : {ParentPipelineName}.")
print(f"CleanedCompanyName : {CleanedCompanyName}.")
print(f"SqlServer : {SqlServer}.")
print(f"SqlDatabase : {SqlDatabase}.")
print(f"WORKSPACE_ID : {WORKSPACE_ID}.")
print(f"PIPELINE_RUN_ID : {PIPELINE_RUN_ID}.")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Global list of transient / retryable SQL and Connection errors
RETRYABLE_ERRORS = (
    "HYT00",                    # Login timeout expired
    "08001",                    # Unable to connect to server / server not found
    "08S01",                    # Communication link failure
    "40613",                    # Database unavailable / serverless scaling
    "Login timeout expired",
    "Communication link failure",
    "A transport-level error has occurred",
    "The service is currently busy",
)

def get_db_connection(max_retries=5, initial_delay=3):
    """
    Connects to Fabric SQL Database using Microsoft Entra ID Access Token.
    Includes exponential retry logic for cold-starts and retryable network errors.
    """
    conn_str = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={SqlServer},1433;"
        f"Database={SqlDatabase};"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        "Connection Timeout=60;"  # Extended timeout for serverless cold-starts
    )
    SQL_COPT_SS_ACCESS_TOKEN = 1256

    for attempt in range(1, max_retries + 1):
        try:
            # Fetch fresh token per attempt
            raw_token = mssparkutils.credentials.getToken("https://database.windows.net/")
            token_bytes = raw_token.encode("utf-16-le")
            token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

            conn = pyodbc.connect(conn_str, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct})
            conn.autocommit = True
            return conn

        except pyodbc.Error as e:
            err_str = str(e)
            is_retryable = any(err in err_str for err in RETRYABLE_ERRORS)
            
            if is_retryable and attempt < max_retries:
                wait_time = round((initial_delay ** attempt) + (attempt * 0.5), 2)
                print(f"[SQL CONN RETRY] Connection failed (Attempt {attempt}/{max_retries}). Retrying in {wait_time}s...", flush=True)
                time.sleep(wait_time)
                continue
            raise e


def execute_sql(query, params=(), fetch=False, max_retries=3):
    """
    Wrapper function to execute queries/SPs safely using Entra ID token auth with retry support.
    """
    for attempt in range(1, max_retries + 1):
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            try:
                cursor.execute(query, params)
                results = None
                
                if fetch:
                    columns = [column[0] for column in cursor.description]
                    results = [dict(zip(columns, row)) for row in cursor.fetchall()]
                
                if not conn.autocommit:
                    conn.commit()
                    
                return results
            finally:
                cursor.close()
                conn.close()

        except pyodbc.Error as e:
            err_str = str(e)
            is_retryable = any(err in err_str for err in RETRYABLE_ERRORS)
            
            if is_retryable and attempt < max_retries:
                print(f"[SQL EXEC RETRY] Execution attempt {attempt}/{max_retries} failed. Retrying...", flush=True)
                time.sleep(2 * attempt)
                continue
            raise e

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# 3. HELPER: API INGESTION
# ============================================================
def ingest_bc_data(url, token, max_pagesize=500):
    """Pulls data from Business Central API, handling @odata.nextLink pagination."""
    headers = {
        "Authorization": f"Bearer {token}",
        "Prefer": f"odata.maxpagesize={max_pagesize}",
        "Accept": f"application/json"
    }

    all_data = []
    current_url = url
    print(f"current_url : {current_url}.")

    while current_url:
        response = requests.get(current_url, headers=headers, timeout=100)
        response.raise_for_status()

        json_resp = response.json()
        page_data = json_resp.get("value", [])
        all_data.extend(page_data)

        current_url = json_resp.get("@odata.nextLink")
        time.sleep(0.01)

    return all_data


# ============================================================
# HELPER: Pre-sanitize Python Dicts before PySpark DataFrame creation
# ============================================================
def cast_ints_to_floats_in_dict(data):
    """
    Recursively converts Python int values (excluding booleans) to float in raw dict lists
    to prevent PySpark [CANNOT_MERGE_TYPE] LongType and DoubleType errors during schema inference.
    """
    if isinstance(data, list):
        return [cast_ints_to_floats_in_dict(item) for item in data]
    elif isinstance(data, dict):
        new_dict = {}
        for k, v in data.items():
            if isinstance(v, bool):
                new_dict[k] = v
            elif isinstance(v, int):
                new_dict[k] = float(v)
            elif isinstance(v, dict):
                new_dict[k] = cast_ints_to_floats_in_dict(v)
            elif isinstance(v, list):
                new_dict[k] = [cast_ints_to_floats_in_dict(i) for i in v]
            else:
                new_dict[k] = v
        return new_dict
    return data


# ============================================================
# HELPER: Clean Business Central column names
# ============================================================
def clean_bc_columns(df):
    """
    Removes leading 'value.' prefix from columns and drops OData metadata columns.
    """
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
        "odata.etag",
    ]

    cols_to_drop = [c for c in unwanted_cols if c in df.columns]

    if cols_to_drop:
        df = df.drop(*cols_to_drop)

    return df


# ============================================================
# HELPER: Align incoming columns to existing Delta target
# ============================================================
def align_to_existing_delta(df_new, tgt_delta_path):
    """
    Aligns incoming DataFrame to the existing Delta table schema.
    If the table does not exist yet, returns df_new as-is.
    """
    try:
        existing_schema = spark.read.format("delta").load(tgt_delta_path).schema
    except Exception:
        print(f"\n[SCHEMA CHECK] Target Delta table at '{tgt_delta_path}' does not exist yet. Creating new schema.")
        return df_new

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

    for field in existing_schema.fields:
        if field.name in source_set:
            incoming_type = df_new.schema[field.name].dataType

            if incoming_type != field.dataType:
                print(
                    f"  [TYPE DRIFT] Column '{field.name}': "
                    f"{incoming_type} -> casting to target type {field.dataType}"
                )
                df_new = df_new.withColumn(
                    field.name, col(field.name).cast(field.dataType)
                )

    ordered_cols = target_cols + [c for c in source_cols if c not in target_set]
    df_new = df_new.select(*ordered_cols)

    return df_new


# ============================================================
# 4 HELPER: Promotes Integer/Long columns to DoubleType
# ============================================================
def promote_integers_to_doubles(df, exclude_cols=["_crda_SourceExecutionId"]):
    """
    Promotes Integer/Long columns to DoubleType to prevent JSON schema drift
    mismatches between whole numbers and floating-point decimals.
    """
    for field in df.schema.fields:
        if isinstance(field.dataType, (LongType, IntegerType)) and field.name not in exclude_cols:
            df = df.withColumn(field.name, col(field.name).cast(DoubleType()))
    return df

# ============================================================
# HELPER: Output a single physical .parquet file
# ============================================================
def save_df_as_single_parquet(df, target_file_path):
    """
    Forces PySpark to output a single physical .parquet file instead of a folder.
    Uses repartition(1) to perform a shuffle, avoiding spark.rpc.message.maxSize limits
    on large driver-created DataFrames.
    """
    temp_dir = f"{target_file_path}_tmp"

    # repartition(1) uses a shuffle phase to keep task payload sizes tiny
    df.repartition(1).write.mode("overwrite").parquet(temp_dir)

    # Locate the generated single part file inside the temp directory
    files = mssparkutils.fs.ls(temp_dir)
    part_file = next(f.path for f in files if f.name.startswith("part-") and f.name.endswith(".parquet"))

    # Remove target destination if present
    if mssparkutils.fs.exists(target_file_path):
        mssparkutils.fs.rm(target_file_path, recurse=True)

    # Move the single parquet file to target destination
    mssparkutils.fs.mv(part_file, target_file_path)

    # Clean up temporary staging directory
    mssparkutils.fs.rm(temp_dir, recurse=True)




# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


# ============================================================
# 5. MAIN EXECUTION (Company Processing Loop)
# ============================================================
failed_entities = []

try:
    print("=" * 80)
    print(f"Starting Consolidated Pipeline for Company: {BcCompanyName}")
    print("=" * 80)

    max_retries= 15

    # 1. Fetch metadata configurations
    config_query = """
        SELECT B.CompanyName, B.ApiGroup, B.ApiEntitySetName
        FROM ETL.BcSourceConfig B
        WHERE B.IsEnabled = 1 AND B.CompanyName = ?
    """
    source_configs = execute_sql(config_query, (BcCompanyName,), fetch=True)

    print(f"Found {len(source_configs)} entities to process for {BcCompanyName}.")

    # 2. Iterate through each API Entity
    for config in source_configs:
        api_entity = config["ApiEntitySetName"]
        staging_projection = f"BC_{CleanedCompanyName}_{api_entity}"

        print(f"\n[{api_entity}] Processing Projection: {staging_projection}")

        # 3. Retrieve Process Metadata via Function
        metadata_query = "SELECT * FROM ETL.FN_GetProcessMetadata(?, ?)"
        metadata_rows = execute_sql(
            metadata_query, (staging_projection, ParentPipelineName), fetch=True
        )

        if not metadata_rows:
            print(f"[{api_entity}] Warning: No metadata found. Skipping.")
            continue

        metadata = metadata_rows[0]

        props_query = "SELECT PropertyName, PropertyValue FROM ETL.Property WHERE PropertyName IN ('Bc365_ApiPublisher', 'Bc365_ApiVersion')"
        props_rows = execute_sql(props_query, fetch=True)
        props = {r["PropertyName"]: r["PropertyValue"] for r in props_rows}

        api_publisher = props.get("Bc365_ApiPublisher")
        api_version = props.get("Bc365_ApiVersion")
        process_id = metadata["ProcessId"]
        pKey_Cols = metadata["PrimaryKeysJson"]
        target_schema = metadata["TableSchema"]
        target_table = metadata["BronzeTableName"]

        print(f"api_publisher : {api_publisher}.")
        print(f"api_version : {api_version}.")
        print(f"process_id : {process_id}.")
        print(f"pKey_Cols : {pKey_Cols}.")

        # 4. Insert Execution Log
        exec_log_query = """
            DECLARE @ExecId INT;
            EXEC [ETL].[usp_InsertExecutionLog] 
                @BatchId = 1, 
                @ProcessId = ?, 
                @ExternalHandlerId = ?, 
                @PipelineName = 'nb_BronzeBcDeltaAppend', 
                @WorkspaceId = ?, 
                @LogDescription = ?;
            SELECT @ExecId AS ExecutionId;
        """
        log_desc = f"Load Bronze for : {staging_projection}"
        execution_id_row = execute_sql(
            exec_log_query,
            (process_id, PIPELINE_RUN_ID, WORKSPACE_ID, log_desc),
            fetch=True,
        )
        execution_id = execution_id_row[0]["ExecutionId"] if execution_id_row else None
        print(f"execution_id : {execution_id}.", flush=True)

        try:
            # 5. Build Paths and Timestamps
            utc_now = datetime.now(timezone.utc)
            year_month = utc_now.strftime("%Y/%m")
            timestamp_str = utc_now.strftime("%d-%H%M%S")

            delta_lake_bronze_folder = (
                f"{metadata['DeltaLakeBronzeFolder']}/{year_month}"
            )
            parquet_filename = f"{timestamp_str}.parquet"

            api_group = metadata["ApiEndPoint"].split("/")[1]
            api_endpoint_str = metadata["ApiEndPoint"].split("/")[2]

            tgt_bc_path = f"Tables/{target_schema}/{target_table}"
            tgt_active_ids_path = f"Tables/{target_schema}/{target_table}_Id"
            watermark_col = metadata.get("WatermarkColumnName", "lastModifiedDateTime")

            # 6. Build API Watermark Filter
            if metadata.get("IngestFirstTime") == 1:
                current_time_str = utc_now.strftime("%Y-%m-%dT%H:%M:%SZ")
                api_filter = f"?$filter={watermark_col} le {current_time_str}"
            else:
                # Convert DB string to valid ISO-8601 DateTimeOffset
                dt = datetime.fromisoformat(str(metadata["BronzeWatermarkValue"]).replace(" ", "T").rstrip("Z"))

                # Format directly with guaranteed 4-digit year padding (:04d)
                watermark_val = f"{dt.year:04d}-{dt.month:02d}-{dt.day:02d}T{dt.hour:02d}:{dt.minute:02d}:{dt.second:02d}Z"

                print(f"dt ...[{dt}] : watermark_val ...[{watermark_val}]", flush=True)

                current_time_str = utc_now.strftime("%Y-%m-%dT%H:%M:%SZ")
                api_filter = f"?$filter={watermark_col} gt {watermark_val} and {watermark_col} le {current_time_str}"

            # 7. Ingest Main Data
            print(f"[{api_entity}] Ingesting Main Data...", flush=True)
            main_url = f"https://api.businesscentral.dynamics.com/v2.0/{Bc365TenantId}/{Bc365UkEnv}/api/{api_publisher}/{api_group}/{api_version}/companies({BcCompanyId})/{api_endpoint_str}{api_filter}"

            try:
                main_data = ingest_bc_data(main_url, Oauth2Token)
            except Exception as e:
                execute_sql(
                    "EXEC [ETL].[usp_UpdateExecutionLog_Failure] @ExecutionId=?, @ProcessId=?, @ErrorMessage=?",
                    (
                        execution_id,
                        process_id,
                        f"IngestBc365/IngestBc365CustomObject: {str(e)}",
                    ),
                )
                raise Exception(f"Main API Ingestion Failed: {str(e)}")
            print(f"[{api_entity}] Ingesting Main Data... SUCCESS", flush=True)

            # 8. Ingest Active IDs
            print(f"[{api_entity}] Ingesting Active IDs...", flush=True)
            ids_url = f"https://api.businesscentral.dynamics.com/v2.0/{Bc365TenantId}/{Bc365UkEnv}/api/{api_publisher}/{api_group}/{api_version}/companies({BcCompanyId})/{api_endpoint_str}?$select=id,lastModifiedDateTime"

            try:
                ids_data = ingest_bc_data(ids_url, Oauth2Token)
            except Exception as e:
                execute_sql(
                    "EXEC [ETL].[usp_UpdateExecutionLog_Failure] @ExecutionId=?, @ProcessId=?, @ErrorMessage=?",
                    (
                        execution_id,
                        process_id,
                        f"IngestBc365/IngestBc365IdsOnly: {str(e)}",
                    ),
                )
                raise Exception(f"Active IDs API Ingestion Failed: {str(e)}")
            print(f"[{api_entity}] Retreived Active IDs... SUCCESS", flush=True)

            # 9. Process DataFrames & Delta Appends
            load_dt = utc_now.strftime("%Y-%m-%d %H:%M:%S")

            if main_data:
                # Pre-sanitize Python dictionary numbers before passing to PySpark
                sanitized_main_data = cast_ints_to_floats_in_dict(main_data)
                df_main_raw = spark.createDataFrame(sanitized_main_data)
                
                # Define full destination file path
                target_main_file_path = f"Files/{delta_lake_bronze_folder}/{parquet_filename}"
                
                df_main = (
                    df_main_raw.withColumn(
                        "_crda_BronzeLoadDateTime", lit(load_dt).cast("timestamp")
                    )
                    .withColumn(
                        "_crda_SourceExecutionId", lit(execution_id).cast("int")
                    )
                    .withColumn("BcCompanyName", lit(BcCompanyName))
                    .withColumn("BcCompanyId", lit(BcCompanyId))
                    .withColumn(
                        "_crda_SourceFileName",
                        lit(f"{delta_lake_bronze_folder}/{parquet_filename}"),
                    )
                )
                df_main = clean_bc_columns(df_main)
                df_main = promote_integers_to_doubles(df_main)
                
                # Save as a single physical .parquet file (e.g. Files/bronze/gLEntries/2026/08/12-130129.parquet)
                save_df_as_single_parquet(df_main, target_main_file_path)
                print(f"[{api_entity}] Main data single file [{target_main_file_path}] saved to Files... SUCCESS", flush=True)

                spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{target_schema}`")
                
                df_main = align_to_existing_delta(df_main, tgt_bc_path)

                max_retries, base_delay_seconds = 5, 3
                for attempt in range(1, max_retries + 1):
                    try:
                        (
                            df_main.write.format("delta")
                            .partitionBy("BcCompanyId")
                            .mode("append")
                            .option("mergeSchema", "true")
                            .save(tgt_bc_path)
                        )
                        break
                    except Exception as append_err:
                        error_str = str(append_err)
                        if (
                            any(err in error_str for err in RETRYABLE_ERRORS)
                            and attempt < max_retries
                        ):
                            time.sleep(
                                round(
                                    (base_delay_seconds**attempt)
                                    + random.uniform(0.5, 1.5),
                                    2,
                                )
                            )
                        else:
                            raise append_err
                print(f"[{api_entity}] Main data to DeltaTable... SUCCESS", flush=True)

                spark.sql(
                    f"CREATE TABLE IF NOT EXISTS `{target_schema}`.`{target_table}` USING DELTA LOCATION '{tgt_bc_path}'"
                )
            if ids_data:
                sanitized_ids_data = cast_ints_to_floats_in_dict(ids_data)
                df_active_raw = spark.createDataFrame(sanitized_ids_data)

                active_ids_folder = metadata.get("BcTmpFolderForIds", "TmpIds")
                target_active_file_path = f"Files/{active_ids_folder}/{CleanedCompanyName}ActiveIds.parquet"
                
                df_active = (
                    df_active_raw.withColumn(
                        "_crda_BronzeLoadDateTime", lit(load_dt).cast("timestamp")
                    )
                    .withColumn(
                        "_crda_SourceExecutionId", lit(execution_id).cast("int")
                    )
                    .withColumn("BcCompanyName", lit(BcCompanyName))
                    .withColumn("BcCompanyId", lit(BcCompanyId))
                    .withColumn(
                        "_crda_SourceFileName",
                        lit(f"{CleanedCompanyName}ActiveIds.parquet"),
                    )
                )
                print(f"[{api_entity}] ActiveIds metadata columns added... SUCCESS", flush=True)
                df_active = clean_bc_columns(df_active)

                # Save as a single physical .parquet file (overwrites existing file)
                save_df_as_single_parquet(df_active, target_active_file_path)
                print(f"[{api_entity}] ActiveIds single file [{target_active_file_path}] saved to Files... SUCCESS", flush=True)
                
                table_exists = False
                try:
                    target_active_delta = DeltaTable.forPath(spark, tgt_active_ids_path)
                    table_exists = True
                except Exception:
                    table_exists = False

                if table_exists:
                    df_active = align_to_existing_delta(df_active, tgt_active_ids_path)

                    raw_keys = (
                        json.loads(pKey_Cols)
                        if isinstance(pKey_Cols, str) and pKey_Cols.startswith("[")
                        else [pKey_Cols]
                    )
                    key_cols = []
                    for item in raw_keys:
                        key_cols.extend(
                            [col.strip() for col in item.split(",") if col.strip()]
                        )

                    merge_condition = " AND ".join(
                        [f"target.{col} = source.{col}" for col in key_cols]
                    )
                    delete_condition = f"target.BcCompanyId = '{BcCompanyId}'"

                    for attempt in range(1, max_retries + 1):
                        try:
                            (
                                target_active_delta.alias("target")
                                .merge(df_active.alias("source"), merge_condition)
                                .whenNotMatchedInsertAll()
                                .whenNotMatchedBySourceDelete(
                                    condition=delete_condition
                                )
                                .execute()
                            )
                            break
                        except Exception as merge_err:
                            error_str = str(merge_err)
                            if (
                                any(err in error_str for err in RETRYABLE_ERRORS)
                                and attempt < max_retries
                            ):
                                time.sleep(
                                    round(
                                        (base_delay_seconds**attempt)
                                        + random.uniform(0.5, 1.5),
                                        2,
                                    )
                                )
                            else:
                                raise merge_err
                    print(f"[{api_entity}] ActiveIds data to DeltaTable... SUCCESS", flush=True)
                else:
                    df_active.write.format("delta").partitionBy("BcCompanyId").mode(
                        "append"
                    ).option("mergeSchema", "true").save(tgt_active_ids_path)

                spark.sql(
                    f"CREATE TABLE IF NOT EXISTS `{target_schema}`.`{target_table}_Id` USING DELTA LOCATION '{tgt_active_ids_path}'"
                )

            # 10. Watermark Calculations
            new_watermark_val = str(metadata["BronzeWatermarkValue"])
            try:
                watermark_df = spark.sql(
                    f"SELECT COALESCE(MAX(`{watermark_col}`), '{new_watermark_val}') AS BronzeWatermarkValue FROM `{target_schema}`.`{target_table}`"
                )
                new_watermark_val = str(watermark_df.collect()[0][0])
                print(f"[{api_entity}] Got latest Watermark [{new_watermark_val}]... SUCCESS", flush=True)
            except Exception as wm_err:
                print(f"[{api_entity}] Could not fetch watermark from table, using default: {wm_err}", flush=True)

            # 11. Log Success & Update First Time Flag
            execute_sql(
                "EXEC [ETL].[usp_UpdateExecutionLog_Success] @ExecutionId=?, @Status=?, @InitialWatermark=?, @UpdatedWatermark=?, @ProcessId=?",
                (
                    execution_id,
                    "BronzeWatermark",
                    str(metadata["BronzeWatermarkValue"]),
                    new_watermark_val,
                    process_id,
                ),
            )

            update_flag_query = """
                UPDATE ETL.ProcessMap 
                SET IngestFirstTime = 0 
                WHERE StagingProjection = ? AND GroupId = 1 AND IngestFirstTime = 1;
            """
            execute_sql(update_flag_query, (staging_projection,))

            print(f"[{api_entity}] Successfully completed.")

        except Exception as inner_e:
            print(f"[{api_entity}] FAILED: {str(inner_e)}")
            failed_entities.append(api_entity)
            try:
                execute_sql(
                    "EXEC [ETL].[usp_UpdateExecutionLog_Failure] @ExecutionId=?, @ErrorMessage=?, @ProcessId=?",
                    (
                        execution_id,
                        f"nb_BronzeBcDeltaAppend: {str(inner_e)}",
                        process_id,
                    ),
                )
            except:
                pass
            continue

except Exception as outer_e:
    # Catches unexpected top-level failures (e.g. database connection down)
    error_msg = f"FAILURE: Critical script error - {str(outer_e)}"
    print("\n" + "=" * 60)
    print("Notebook failed critically.")
    print(error_msg)
    print("=" * 60)
    mssparkutils.notebook.exit(error_msg)

# ============================================================
# FINAL STATUS EXIT (Outside of outer try-except)
# ============================================================
if failed_entities:
    error_msg = f"FAILURE: Completed with failures in entities: {', '.join(failed_entities)}"
    print(f"\n{error_msg}")
    mssparkutils.notebook.exit(error_msg)
else:
    print(f"\nSUCCESS: All entities processed successfully for {BcCompanyName}.")
    mssparkutils.notebook.exit("SUCCESS")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }
