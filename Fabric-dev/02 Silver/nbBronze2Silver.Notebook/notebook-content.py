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

# =============================================================================
# Notebook  : nb_LoadSilverDeltaTables  (v2 – reviewed / hardened)
# Purpose   : Generic, metadata-driven ingestion from Bronze → Silver (SCD2)
# Lakehouse : Attached to lh_silver
# Author    : Mazhar
# Notes     : Designed to be environment-agnostic (dev/test/prod).
#             No code changes required when promoting between environments.
#             All environment-specific config is passed via parameters.
#
# CHANGE LOG (v2) – see inline "FIX #" / "PERF #" markers:
#   FIX  #2  Soft-delete now guarded against an empty active-IDs source.
#   FIX  #3  SCD2 expire + insert collapsed into ONE atomic MERGE.
#   FIX  #4  RowHash is null-safe (null position no longer collides).
#   FIX  #5  Robust ISO timestamp parsing (7-digit fractions / trailing 'Z').
#   FIX  #6  Dedup preserves intermediate SCD2 versions (PK + watermark).
#   FIX  #7  Source-watermark boundary is inclusive (>=), dupes blocked by hash.
#   FIX  #8  Removed duplicate/unused lakehouse constants; helper renamed.
#   PERF #1  Emptiness tests use isEmpty() instead of full count().
#   PERF #2  Silver schema read reuses the DeltaTable handle (one read).
#   PERF #3  Current-version lookup restricted to incoming keys (broadcast).
#   PERF #4  Soft-delete full-table sweep is opt-in (pRunSoftDelete).
#   PERF #5  The deduped batch frame is cached (reused by transform/hash/merge).
#   STYLE    typing.Any, single annotation, tighter identifier regex, etc.
#
# IMPORTANT: The exception-handling block (SECTION 7) is intentionally
#            UNCHANGED from the original notebook.
# =============================================================================

# =============================================================================
# SECTION 1 – PARAMETERS
# All values are injected by the orchestrator (e.g. Data Factory / Fabric
# Pipeline). This cell must be tagged as a "parameter cell" in Fabric.
# Defaults below are illustrative only and should not be relied upon in production.
# =============================================================================
pTargetSchema       = 'Kantata'
pBronzeTableShortcut = "BronzeKantata.BusinessUnit"
pSilverTableName    = "Kantata.HISTORY_BusinessUnit"
pWatermarkColumnName  = "SystemModstamp"
pWatermarkColumnValue = "2000-12-15T17:59:31"
pBronzeDataLoadWatermarkColumn = "_crda_BronzeLoadDateTime"
pBronzeDataLoadWatermarkValue  = "2000-03-03T13:33:21.9820423Z"
pPrimaryKeysJson    = '["Id"]'
pHashColumnsJson    = '["Budget_Code__c","CreatedDate","CurrencyIsoCode","isActive__c","isDefault__c","IsDeleted","KimbleOne__AllowanceScheme__c","KimbleOne__BusinessUnit__c","KimbleOne__BusinessUnitGroup__c","KimbleOne__Calendar__c","KimbleOne__CreditNoteFooter__c","KimbleOne__ExpenseItemExchangeRateTolerancePct__c","KimbleOne__ExpenseItemSubmissionDays__c","KimbleOne__ExpensesTaxCodeRule__c","KimbleOne__InternalAccount__c","KimbleOne__InvoiceFooter__c","KimbleOne__InvoicePaymentTermDays__c","KimbleOne__InvoiceTaxCodeNumber__c","KimbleOne__InvoicingAddress__c","KimbleOne__InvoicingBusinessUnitName__c","KimbleOne__InvoicingCity__c","KimbleOne__InvoicingCountry__c","KimbleOne__InvoicingCurrencyIsoCode__c","KimbleOne__InvoicingName__c","KimbleOne__InvoicingPostalCode__c","KimbleOne__InvoicingState__c","KimbleOne__InvoicingStreet__c","KimbleOne__InvoicingStreetName__c","KimbleOne__IsActive__c","KimbleOne__IsOperatingEntity__c","KimbleOne__IsPrimaryOrganisationalEntity__c","KimbleOne__IsSecondaryOrganisationalEntity__c","KimbleOne__IsTradingEntity__c","KimbleOne__LogoDocumentName__c","KimbleOne__TaxCode__c","KimbleOne__TaxCodeReference__c","KimbleOne__TimePattern__c","KimbleOne__TimePatternRule__c","KimbleOne__TimePatternVariant__c","LastReferencedDate","Name","OwnerId","Sage200CostCentreCode__c","Sage200DepartmentCode__c","SageDepartmentCode__c"]'
pTransformationsJson= '{"computed": {"BusinessUnitName": "Name"}}'
pExecutionId    = 1073
pProcessId      = 10

# PERF #4 – Full-table soft-delete sweep (STEP 11) scans the whole Silver table
# via NOT MATCHED BY SOURCE. Keep it opt-in so it runs on a cadence (e.g. nightly)
# rather than on every incremental micro-batch.
pRunSoftDelete  = True

# Debug toggle – when True, verbose DEBUG lines are emitted to aid support.
pDebug          = True


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
import re
import traceback
from typing import Any                      # STYLE: proper type for parse_json_param
from datetime import datetime, timezone
from pyspark.sql import DataFrame, functions as F
from pyspark.sql.types import (
    StringType, IntegerType, LongType, DoubleType,
    FloatType, BooleanType, DateType, TimestampType, DecimalType
)
from pyspark.sql.window import Window
from delta.tables import DeltaTable
from notebookutils import mssparkutils

# Normalise all timestamp casts to UTC so watermark string comparisons are
# timezone-consistent regardless of cluster/session default.
spark.conf.set("spark.sql.session.timeZone", "UTC")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }

# CELL ********************

# =============================================================================
# SECTION 2 – CONSTANTS & CONFIGURATION
# Centralised place for all "magic values".
# NOTE: ACTIVE_IDs_TABLE derives from pBronzeTableShortcut which is injected
#       by the parameter cell before this cell executes.
# =============================================================================

# Bronze lakehouse name (consistent across envs)
BRONZE_LAKEHOUSE  = "lh_BronzeLayer"   
BRONZE_LAKEHOUSE  = "lh_BronzeLayer"
SILVER_LAKEHOUSE  = "lh_SilverLayer"
# Both Bronze and Silver are read via the attached lakehouse Tables/ path.
LAKEHOUSE_TABLES_ROOT = "Tables"

SCD2_ACTIVE_FROM_COL  = "_crda_ActiveFromDateTime"
SCD2_ACTIVE_TO_COL    = "_crda_ActiveToDateTime"
SCD2_IS_CURRENT_COL   = "isCurrent"
SCD2_ROW_HASH_COL     = "_crda_RowHash"
IS_DELETED_COL        = "_crda_isDeleted"
SCD2_OPEN_END_DATE    = "9999-12-31 23:59:59"

META_SILVER_LOAD_DT_COL  = "_crda_SilverLoadDateTime"
META_CREATED_EXEC_ID_COL = "_crda_CreatedExecutionId"
META_UPDATED_EXEC_ID_COL = "_crda_UpdatedExecutionId"
ACTIVE_IDs_TABLE         = pBronzeTableShortcut + "_Id"

EXPIRE_OFFSET_MS = 1  

# FIX #4 – sentinel used inside the RowHash so a NULL in one column cannot be
# confused with a NULL (or the same value) in an adjacent column.
HASH_NULL_TOKEN = "\u2400"   # ␀ (SYMBOL FOR NULL) – extremely unlikely in real data.

# PERF: only run OPTIMIZE/ZORDER when a merge inserts at least this many rows
OPTIMIZE_MIN_INSERTS = 50000

# STYLE – backticks/brackets removed: they can defeat quote_table_name() and are
# never legitimately part of a schema/table identifier passed by the orchestrator.
_SAFE_IDENTIFIER_RE = re.compile(r'^[A-Za-z0-9_.-]+$')

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# =============================================================================
# SECTION 3 – HELPERS: log / debug / validate_identifier / parse_json_param /
#              map_spark_type / to_ts
# =============================================================================

def log(message: str, level: str = "INFO"):
    """Simple structured logger – prefix with timestamp and level."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{ts}] [{level}] {message}")


def debug(message: str):
    """Verbose logger – only emits when pDebug is True (support/maintenance aid)."""
    if pDebug:
        log(message, "DEBUG")


def validate_identifier(value: str, param_name: str) -> str:
    """
    Validate that a value used as a SQL identifier (table name, column name)
    contains only safe characters.  Raises ValueError on unsafe input.
    """
    if not _SAFE_IDENTIFIER_RE.match(value):
        raise ValueError(
            f"Parameter '{param_name}' contains unsafe characters: {value!r}. "
            "Only alphanumerics, underscores, dots and hyphens are allowed."
        )
    debug(f"    validate_identifier OK: {param_name}={value!r}")
    return value


def parse_json_param(param_name: str, raw_value: str) -> Any:
    """
    Safely parse a JSON string parameter.
    Raises a ValueError with a descriptive message on failure.
    """
    try:
        parsed = json.loads(raw_value)
        debug(f"    parse_json_param '{param_name}' -> {parsed!r}")
        return parsed
    except json.JSONDecodeError as exc:
        raise ValueError(f"Parameter '{param_name}' is not valid JSON: {exc}") from exc


def map_spark_type(type_str: str):
    """
    Convert a string type descriptor (from pTransformationsJson) to a Spark
    DataType object. Extend this mapping as required.
    """
    mapping = {
        "string":    StringType(),
        "int":       IntegerType(),
        "integer":   IntegerType(),
        "long":      LongType(),
        "bigint":    LongType(),
        "double":    DoubleType(),
        "float":     FloatType(),
        "boolean":   BooleanType(),
        "bool":      BooleanType(),
        "date":      DateType(),
        "timestamp": TimestampType(),
    }
    lower = type_str.lower().strip()
    if lower.startswith("decimal"):
        inner = lower.replace("decimal", "").strip("() ")
        parts = inner.split(",")
        precision = int(parts[0]) if len(parts) > 0 else 18
        scale     = int(parts[1]) if len(parts) > 1 else 4
        return DecimalType(precision, scale)
    if lower not in mapping:
        raise ValueError(f"Unsupported type descriptor '{type_str}' in pTransformationsJson.")
    return mapping[lower]

def to_ts(value: str):
    """
    FIX #5 – Robust ISO-8601 → Spark timestamp conversion.
    Plain `CAST(str AS TIMESTAMP)` can return NULL for:
      * >6 fractional-second digits (Spark supports microseconds only), e.g.
        '2000-03-03T13:33:21.9820423Z'
      * a trailing 'Z' zone designator, depending on Spark version/config.
    We trim the fraction to 6 digits and normalise 'Z' → '+00:00' so parsing is
    deterministic. A NULL watermark would silently read the whole (or none) of
    the source, so this must be reliable.
    Returns a Spark Column (literal timestamp).
    """
    cleaned = re.sub(r'(\.\d{6})\d+', r'\1', value).replace("Z", "+00:00")
    debug(f"    to_ts('{value}') -> '{cleaned}'")
    return F.to_timestamp(F.lit(cleaned))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# =============================================================================
# SECTION 4 – HELPER: apply_transformations
# FIX #9 – Removed df.limit(1).count() — it added overhead without reliably
#           surfacing lazy-evaluation errors; errors surface during the actual
#           write/merge operations instead.
# =============================================================================

def apply_transformations(df: DataFrame, transformations: dict) -> DataFrame:
    """
    Apply metadata-driven transformations to a DataFrame.
    Any error is logged and re-raised so the calling try/except block
    in the main execution section can catch it correctly.
    """
    try:
        # -- 5a. Rename columns -----------------------------------------------
        rename_map: dict = transformations.get("rename", {})
        for old_name, new_name in rename_map.items():
            if old_name in df.columns:
                log(f"  Renaming column '{old_name}' → '{new_name}'")
                df = df.withColumnRenamed(old_name, new_name)
            else:
                log(f"  WARN: Rename source column '{old_name}' not found – skipping.", "WARN")

        # -- 5b. Cast columns -------------------------------------------------
        cast_map: dict = transformations.get("cast", {})
        for col_name, type_str in cast_map.items():
            if col_name in df.columns:
                target_type = map_spark_type(type_str)
                log(f"  Casting '{col_name}' → {type_str}")
                df = df.withColumn(col_name, F.col(col_name).cast(target_type))
            else:
                log(f"  WARN: Cast target column '{col_name}' not found – skipping.", "WARN")

        # -- 5c. Cleanse columns ----------------------------------------------
        cleanse_map: dict = transformations.get("cleanse", {})
        for col_name, rules in cleanse_map.items():
            if col_name not in df.columns:
                log(f"  WARN: Cleanse target column '{col_name}' not found – skipping.", "WARN")
                continue
            log(f"  Cleansing column '{col_name}' with rules: {rules}")
            col_expr = F.col(col_name)

            if rules.get("trim", False):
                col_expr = F.trim(col_expr)
            if rules.get("upper", False):
                col_expr = F.upper(col_expr)
            if rules.get("lower", False):
                col_expr = F.lower(col_expr)

            replace_null = rules.get("replace_nulls")
            if replace_null is not None:
                col_expr = F.coalesce(col_expr, F.lit(replace_null))

            regex_rule = rules.get("regex_replace")
            if regex_rule:
                col_expr = F.regexp_replace(col_expr, regex_rule["pattern"], regex_rule["replacement"])

            df = df.withColumn(col_name, col_expr)

        # -- 5d. Computed columns ---------------------------------------------
        computed_map: dict = transformations.get("computed", {})
        for new_col, sql_expr in computed_map.items():
            log(f"  Adding computed column '{new_col}' = {sql_expr}")
            df = df.withColumn(new_col, F.expr(sql_expr))

        # -- 5e. Drop columns -------------------------------------------------
        drop_list: list = transformations.get("drop", [])
        for col_name in drop_list:
            if col_name in df.columns:
                log(f"  Dropping column '{col_name}'")
                df = df.drop(col_name)
            else:
                log(f"  WARN: Drop target column '{col_name}' not found – skipping.", "WARN")

        debug(f"  apply_transformations output columns: {df.columns}")
        return df

    except Exception as exc:
        log(f"  ERROR in apply_transformations: {str(exc)}", "ERROR")
        log(traceback.format_exc(), "ERROR")
        raise


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# =============================================================================
# SECTION 5 – HELPERS: compute_row_hash / add_scd2_meta_columns /
#              align_schema / table_path / ensure_schema_exists /
#              quote_table_name / register_delta_table
# =============================================================================

def compute_row_hash(df: DataFrame, hash_columns: list) -> DataFrame:
    """
    Compute a SHA2-256 hash over the specified columns and store in _crda_RowHash.
    Raises if no valid hash columns exist, so we never silently hash an empty
    string (which would make every row look identical and break change detection).

    FIX #4 – Each column is wrapped in COALESCE(..., HASH_NULL_TOKEN) BEFORE the
    concat_ws. concat_ws SKIPS nulls, so without a sentinel the tuples
    ('a', NULL, 'b') and ('a', 'b', NULL) would hash identically and a genuine
    change could be missed (no new SCD2 version written).
    """
    try:
        valid_cols = [c for c in hash_columns if c in df.columns]
        missing    = [c for c in hash_columns if c not in df.columns]
        if missing:
            log(f"  WARN: Hash columns not found in DataFrame – excluded: {missing}", "WARN")

        if not valid_cols:
            raise ValueError(
                "compute_row_hash: no valid hash columns present in DataFrame; "
                "cannot compute a meaningful RowHash."
            )

        debug(f"  compute_row_hash over columns: {valid_cols}")
        hash_expr = F.sha2(
            F.concat_ws(
                "|",
                *[
                    F.coalesce(F.col(c).cast(StringType()), F.lit(HASH_NULL_TOKEN))
                    for c in valid_cols
                ]
            ),
            256
        )
        return df.withColumn(SCD2_ROW_HASH_COL, hash_expr)

    except Exception as exc:
        log(f"  ERROR in compute_row_hash: {str(exc)}", "ERROR")
        raise


def add_scd2_meta_columns(
    df: DataFrame,
    watermark_col: str,
    execution_id: int
) -> DataFrame:
    """
    Append all required SCD2 and audit metadata columns to the incoming records.

    NOTE: The Silver load timestamp now uses F.current_timestamp() (full
    precision, session-UTC consistent) rather than a seconds-truncated Python
    string, so audit ordering within a run is preserved.
    """
    try:
        df = (
            df
            .withColumn(SCD2_ACTIVE_FROM_COL, F.col(watermark_col).cast(TimestampType()))
            .withColumn(SCD2_ACTIVE_TO_COL, F.lit(SCD2_OPEN_END_DATE).cast(TimestampType()))
            .withColumn(SCD2_IS_CURRENT_COL, F.lit(True).cast(BooleanType()))
            .withColumn(IS_DELETED_COL, F.lit(False).cast(BooleanType()))
            .withColumn(META_SILVER_LOAD_DT_COL, F.current_timestamp())
            .withColumn(META_CREATED_EXEC_ID_COL, F.lit(execution_id).cast(IntegerType()))
            .withColumn(META_UPDATED_EXEC_ID_COL, F.lit(execution_id).cast(IntegerType()))
        )
        debug(f"  add_scd2_meta_columns output columns: {df.columns}")
        return df

    except Exception as exc:
        log(f"  ERROR in add_scd2_meta_columns: {str(exc)}", "ERROR")
        raise


def align_schema(source_df: DataFrame, target_df: DataFrame) -> DataFrame:
    """SCHEMA DRIFT HANDLER – add target columns missing from source as typed NULLs."""
    try:
        target_schema = {field.name: field.dataType for field in target_df.schema}
        source_cols   = set(source_df.columns)

        for col_name, col_type in target_schema.items():
            if col_name not in source_cols:
                log(f"  Schema drift (source→target): Adding missing column '{col_name}' as NULL")
                source_df = source_df.withColumn(col_name, F.lit(None).cast(col_type))

        return source_df

    except Exception as exc:
        log(f"  ERROR in align_schema: {str(exc)}", "ERROR")
        raise


def table_path(table_name: str) -> str:
    """
    FIX #8 – Generic Delta Tables/ path builder (renamed from silver_table_path;
    it is used for BOTH the Bronze shortcut and the Silver table, so a
    silver-specific name was misleading).
    Accepts 'schema.table' or bare 'table'.
    """
    parts = table_name.split(".", 1)
    if len(parts) == 2:
        schema, tbl = parts
        return f"{LAKEHOUSE_TABLES_ROOT}/{schema}/{tbl}"
    return f"{LAKEHOUSE_TABLES_ROOT}/{table_name}"


def quote_table_name(table_name: str) -> str:
    """Backtick-quote a (possibly dot-notation) table name for safe SQL by-name use."""
    parts = table_name.split(".", 1)
    if len(parts) == 2:
        return f"`{parts[0]}`.`{parts[1]}`"
    return f"`{table_name}`"


def ensure_schema_exists(table_name: str):
    """Create the schema (folder) in the lakehouse if it does not already exist."""
    try:
        parts = table_name.split(".", 1)
        if len(parts) == 2:
            schema = parts[0]
            log(f"  Ensuring schema '{schema}' exists in lh_silver")
            spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{schema}`")

    except Exception as exc:
        log(f"  ERROR in ensure_schema_exists: {str(exc)}", "ERROR")
        raise


def register_delta_table(table_name: str, path: str):
    """
    Register a path-created Delta table in the catalog so subsequent name-based
    SQL (ALTER / REFRESH / MERGE) works on the very first run.
    (In Fabric, writing under Tables/<schema>/<table> usually auto-registers;
    this is belt-and-braces for the first run and is a no-op if already present.)
    """
    try:
        qualified = quote_table_name(table_name)
        log(f"  Registering Delta table {qualified} at LOCATION '{path}'")
        spark.sql(f"CREATE TABLE IF NOT EXISTS {qualified} USING DELTA LOCATION '{path}'")

    except Exception as exc:
        log(f"  ERROR in register_delta_table: {str(exc)}", "ERROR")
        raise

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# =============================================================================
# SECTION 6 – MAIN EXECUTION
# =============================================================================

# ── Safe defaults — defined BEFORE the try so finally can always reference them.
execution_status         = "FAILURE"
error_msg                = ""
run_datetime_str         = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
execution_id             = 0
process_id               = 0
watermark_filtered_count = 0
deduped_count            = 0
insert_count             = 0
# No-data / early-failure watermark must ECHO the incoming watermark, never a
# hard-coded past date — otherwise the orchestrator would regress the watermark.
silver_watermark         = pWatermarkColumnValue

try:
    log("=" * 70)
    log("Bronze → Silver SCD2 Notebook – START")
    log("=" * 70)

    # Normalise all timestamp casts to UTC so watermark string comparisons are
    # timezone-consistent regardless of cluster/session default.
    spark.conf.set("spark.sql.session.timeZone", "UTC")
    debug(f"  spark.sql.session.timeZone = {spark.conf.get('spark.sql.session.timeZone')}")

    # ── STEP 1: Validate & parse parameters ───────────────────────────────────
    log("STEP 1: Validating and parsing input parameters")

    if not pBronzeTableShortcut:
        raise ValueError("pBronzeTableShortcut is required and must not be empty.")
    if not pSilverTableName:
        raise ValueError("pSilverTableName is required and must not be empty.")

    validate_identifier(pBronzeTableShortcut,           "pBronzeTableShortcut")
    validate_identifier(pSilverTableName,               "pSilverTableName")
    validate_identifier(pWatermarkColumnName,           "pWatermarkColumnName")
    validate_identifier(pBronzeDataLoadWatermarkColumn, "pBronzeDataLoadWatermarkColumn")

    primary_keys: list = parse_json_param("pPrimaryKeysJson", pPrimaryKeysJson)

    # Empty / blank pHashColumnsJson is allowed → default to all non-key columns later.
    # STYLE: annotate the variable once, not in every branch.
    hash_columns: list
    if pHashColumnsJson and pHashColumnsJson.strip():
        hash_columns = parse_json_param("pHashColumnsJson", pHashColumnsJson)
    else:
        hash_columns = []

    transformations = parse_json_param("pTransformationsJson", pTransformationsJson)

    if not isinstance(primary_keys, list) or len(primary_keys) == 0:
        raise ValueError("pPrimaryKeysJson must be a non-empty JSON array.")
    if not isinstance(hash_columns, list):
        raise ValueError("pHashColumnsJson must be a JSON array (or empty).")

    for pk in primary_keys:
        validate_identifier(pk, f"pPrimaryKeysJson[{pk}]")
    for hc in hash_columns:
        validate_identifier(hc, f"pHashColumnsJson[{hc}]")

    execution_id: int = int(pExecutionId)
    process_id:   int = int(pProcessId)

    log(f"  pBronzeTableShortcut              : {pBronzeTableShortcut}")
    log(f"  pSilverTableName                  : {pSilverTableName}")
    log(f"  pTargetSchema                     : {pTargetSchema}")
    log(f"  pWatermarkColumnName              : {pWatermarkColumnName}")
    log(f"  pWatermarkColumnValue             : {pWatermarkColumnValue}")
    log(f"  pBronzeDataLoadWatermarkColumn    : {pBronzeDataLoadWatermarkColumn}")
    log(f"  pBronzeDataLoadWatermarkValue     : {pBronzeDataLoadWatermarkValue}")
    log(f"  Primary keys                      : {primary_keys}")
    log(f"  Hash columns (supplied)           : {hash_columns}")
    log(f"  pRunSoftDelete                    : {pRunSoftDelete}")
    log(f"  Execution ID                      : {execution_id}")
    log(f"  Process ID                        : {process_id}")

    # ── STEP 2: Read new Bronze records using Bronze Load watermark ───────────
    log("STEP 2: Reading new Bronze records since last Bronze load watermark")

    bronze_source_path = table_path(pBronzeTableShortcut)
    debug(f"  Bronze source Delta path: {bronze_source_path}")

    # PERF #5 – Cache the Bronze slice once so the emptiness test + downstream
    # watermark filter / dedup reuse a single physical scan of Bronze.
    bronze_df = (
        spark.read
             .format("delta")
             .load(bronze_source_path)
             .filter(
                 # FIX #5 – robust timestamp parse for the Bronze-load watermark.
                 F.col(pBronzeDataLoadWatermarkColumn) > to_ts(pBronzeDataLoadWatermarkValue)
             )
             .cache()
    )

    # PERF #1 – short-circuit on emptiness without paying for a full count().
    if bronze_df.isEmpty():
        log("  No new bronze records ingested. Exiting with SUCCESS (nothing to process).")
        bronze_df.unpersist()
        # silver_watermark stays == pWatermarkColumnValue (no regression)
        execution_status = "SUCCESS"

    else:
        # Count only now that we know there IS data (used purely for logging).
        new_record_count = bronze_df.count()
        log(f"  Bronze records after Bronze load watermark filter: {new_record_count:,}")

        # ── STEP 3: Filter on Source Watermark ────────────────────────────────
        log("STEP 3: Filtering on source watermark (SystemModstamp)")

        # FIX #7 – inclusive (>=) so rows sharing the exact boundary timestamp are
        # not dropped. Duplicate SCD2 versions are prevented downstream because
        # the merge only inserts rows whose RowHash differs from the current row.
        bronze_wm_df = bronze_df.filter(
            F.col(pWatermarkColumnName) >= to_ts(pWatermarkColumnValue)
        )

        if bronze_wm_df.isEmpty():                                   # PERF #1
            log("  No new bronze records found after source watermark filter. Exiting with SUCCESS (nothing to process).")
            bronze_df.unpersist()
            # silver_watermark stays == pWatermarkColumnValue (no regression)
            execution_status = "SUCCESS"

        else:
            watermark_filtered_count = bronze_wm_df.count()          # logging / payload
            log(f"  Records after source watermark filter: {watermark_filtered_count:,}")

            # ── STEP 4: Deduplicate Bronze records ─────────────────────────────
            log("STEP 4: Deduplicating Bronze records (collapse exact PK+watermark duplicates)")

            # FIX #6 – partition by PK *and* the source watermark, so distinct
            # changes for the same key across the batch are PRESERVED (intermediate
            # SCD2 versions). Only exact same-key/same-timestamp rows collapse.
            # (Full ordered replay of intermediate versions requires the merge to
            #  apply them in watermark order – see note in STEP 8.)
            dedup_window = (
                Window
                .partitionBy(*[F.col(k) for k in primary_keys], F.col(pWatermarkColumnName))
                .orderBy(F.col(pWatermarkColumnName).desc())
            )

            # PERF #5 – cache the deduped frame; it is reused by transform → hash →
            # SCD2 meta → merge, so materialising it once avoids re-scanning Bronze.
            bronze_deduped_df = (
                bronze_wm_df
                .withColumn("_dedup_rank", F.row_number().over(dedup_window))
                .filter(F.col("_dedup_rank") == 1)
                .drop("_dedup_rank")
                .cache()
            )

            deduped_count = bronze_deduped_df.count()   # single action → materialises cache
            log(f"  Records after deduplication: {deduped_count:,}")

            # Silver watermark = max source watermark of the processed batch.
            # Computed here (reusing the cached deduped frame) to avoid a Silver scan.
            _batch_wm = bronze_deduped_df.agg(F.max(F.col(pWatermarkColumnName))).collect()[0][0]
            silver_watermark = str(_batch_wm) if _batch_wm is not None else pWatermarkColumnValue
            log(f"  Batch source watermark: {silver_watermark}")

            # Bronze slice cache no longer needed – the deduped cache supersedes it.
            bronze_df.unpersist()

            # ── STEP 5: Apply metadata-driven transformations ──────────────────
            log("STEP 5: Applying metadata-driven transformations / cleansing / computed columns")
            transformed_df = apply_transformations(bronze_deduped_df, transformations)

            # ── STEP 6: Compute RowHash ────────────────────────────────────────
            log("STEP 6: Computing RowHash over hash columns")
            if not hash_columns:
                hash_columns = [c for c in transformed_df.columns if c not in primary_keys]
                log(f"  No hash columns supplied; defaulting to all non-key columns: {hash_columns}")
            transformed_df = compute_row_hash(transformed_df, hash_columns)

            # ── STEP 7: Add SCD2 & audit metadata columns ──────────────────────
            log("STEP 7: Adding SCD2 and audit metadata columns")
            transformed_df = add_scd2_meta_columns(
                df            = transformed_df,
                watermark_col = pWatermarkColumnName,
                execution_id  = execution_id
            )

            # ── STEP 8: Silver table creation / atomic SCD2 merge ──────────────
            log("STEP 8: Checking if Silver Delta table exists; creating if not")

            ensure_schema_exists(pSilverTableName)
            silver_path       = table_path(pSilverTableName)
            silver_tbl_q      = quote_table_name(pSilverTableName)
            table_exists      = DeltaTable.isDeltaTable(spark, silver_path)
            table_was_created = not table_exists
            debug(f"  silver_path={silver_path} | exists={table_exists}")

            if not table_exists:
                log(f"  Silver table '{pSilverTableName}' does not exist. Creating now.")
                (
                    transformed_df.write
                    .format("delta")
                    .mode("overwrite")
                    .option("overwriteSchema", "true")
                    .save(silver_path)
                )
                # Register in the catalog so name-based SQL below works first run.
                register_delta_table(pSilverTableName, silver_path)
                insert_count = deduped_count
                log(f"  Silver table created with {deduped_count:,} initial records.")

            else:
                log(f"  Silver table '{pSilverTableName}' exists. Performing atomic SCD2 merge.")

                # PERF #2 – one handle, reused for both schema alignment and merge.
                silver_delta = DeltaTable.forPath(spark, silver_path)
                existing_silver_schema_df = silver_delta.toDF().limit(0)
                transformed_df = align_schema(transformed_df, existing_silver_schema_df)

                # PERF #5 – cache the merge source (read multiple times below).
                transformed_df.cache()
                incoming_count = transformed_df.count()  # materialise
                debug(f"  transformed_df cached ({incoming_count:,} rows).")

                # PERF #3 – Current-version lookup restricted to the INCOMING keys
                # only (broadcast semi-join), so we do not scan/cache every current
                # row in a potentially huge dimension.
                incoming_keys = transformed_df.select(*primary_keys).distinct()
                current_silver_df = (
                    silver_delta.toDF()
                    .filter(F.col(SCD2_IS_CURRENT_COL) == True)          # noqa: E712 (Spark col)
                    .select(*primary_keys, SCD2_ROW_HASH_COL)
                    .join(F.broadcast(incoming_keys), on=primary_keys, how="left_semi")
                    .cache()
                )
                debug(f"  current_silver_df (incoming keys only) rows: {current_silver_df.count():,}")

                # ── FIX #3 – Single ATOMIC SCD2 MERGE ──────────────────────────
                # The original code expired changed rows (Step A MERGE) and then
                # appended new versions (Step B append) in two separate commits –
                # a failure between them left history inconsistent.
                #
                # We now stage the batch so ONE MERGE both expires old versions and
                # inserts new ones, using the classic "double-row" technique:
                #
                #   * new_or_changed = incoming rows whose (PK, RowHash) is NOT an
                #     existing CURRENT row (i.e. brand-new keys OR changed keys).
                #   * changed        = subset of new_or_changed whose PK already
                #     exists as a current row (needs the old version expired).
                #
                # Staged rows carry helper merge-key columns (mk_<pk>):
                #   * INSERT copies  -> mk_<pk> = NULL  → never match → INSERT new version.
                #   * EXPIRE copies  -> mk_<pk> = <pk>  → match current (hash differs)
                #                                          → UPDATE (close the old row).
                # Brand-new keys get only an INSERT copy, so they are never
                # accidentally inserted twice.
                log("  Building atomic-merge staging set (insert + expire copies)")

                # Rows that are genuinely new or changed (unchanged rows excluded).
                new_or_changed = (
                    transformed_df.alias("incoming")
                    .join(
                        current_silver_df.alias("existing"),
                        on=(
                            [F.col(f"incoming.{k}") == F.col(f"existing.{k}") for k in primary_keys]
                            + [F.col(f"incoming.{SCD2_ROW_HASH_COL}") == F.col(f"existing.{SCD2_ROW_HASH_COL}")]
                        ),
                        how="left_anti",
                    )
                    .cache()
                )
                new_or_changed_count = new_or_changed.count()
                debug(f"  new_or_changed rows (new + changed): {new_or_changed_count:,}")

                # Of those, which PKs already exist as a current row → must expire.
                current_keys_only = current_silver_df.select(*primary_keys).distinct()
                changed = new_or_changed.join(
                    F.broadcast(current_keys_only), on=primary_keys, how="left_semi"
                )

                # Preserve pk column data types so the NULL merge-keys union cleanly.
                pk_types = {f.name: f.dataType for f in transformed_df.schema if f.name in primary_keys}
                insert_copies = new_or_changed.select(
                    *[F.lit(None).cast(pk_types[k]).alias(f"mk_{k}") for k in primary_keys],
                    "*",
                )
                expire_copies = changed.select(
                    *[F.col(k).alias(f"mk_{k}") for k in primary_keys],
                    "*",
                )
                staged = insert_copies.unionByName(expire_copies)

                # Merge ON: match a CURRENT target row with same PK but different hash.
                on_condition = " AND ".join([f"t.{k} = s.mk_{k}" for k in primary_keys])
                on_condition += (
                    f" AND t.{SCD2_IS_CURRENT_COL} = true "
                    f"AND t.{SCD2_ROW_HASH_COL} <> s.{SCD2_ROW_HASH_COL}"
                )
                debug(f"  MERGE ON: {on_condition}")

                # Close the old version: ActiveTo just before the new ActiveFrom.
                expire_expr = (
                    F.col(f"s.{SCD2_ACTIVE_FROM_COL}")
                    - F.expr(f"INTERVAL {EXPIRE_OFFSET_MS} MILLISECONDS")
                )

                # INSERT values = every real column (exclude the mk_ helpers).
                insert_values = {c: f"s.{c}" for c in transformed_df.columns}

                log("  Executing atomic SCD2 MERGE (expire changed + insert new versions)")
                (
                    silver_delta.alias("t")
                    .merge(staged.alias("s"), on_condition)
                    .whenMatchedUpdate(set={
                        SCD2_ACTIVE_TO_COL      : expire_expr,
                        SCD2_IS_CURRENT_COL     : F.lit(False),
                        META_UPDATED_EXEC_ID_COL: F.lit(execution_id).cast(IntegerType()),
                    })
                    .whenNotMatchedInsert(values=insert_values)
                    .execute()
                )

                # Pull the true inserted-row count from the Delta operation metrics
                # (drives the conditional OPTIMIZE decision below).
                op_metrics = silver_delta.history(1).select("operationMetrics").collect()[0][0]
                insert_count = int(op_metrics.get("numTargetRowsInserted", 0))
                updated_ct   = int(op_metrics.get("numTargetRowsUpdated", 0))
                log(f"  MERGE complete: inserted={insert_count:,}, expired(updated)={updated_ct:,}")
                debug(f"  Full merge operationMetrics: {dict(op_metrics)}")

                # Release caches — no longer needed after the merge is committed.
                new_or_changed.unpersist()
                transformed_df.unpersist()
                current_silver_df.unpersist()

            # ── STEP 10: Optimise Silver table ─────────────────────────────────
            log("STEP 10: Maintaining stats + conditional OPTIMIZE on Silver Delta table")
            zorder_cols = ", ".join(primary_keys)
            # Include the watermark column so max()/incremental reads can data-skip.
            stats_cols  = ", ".join(dict.fromkeys(primary_keys + [pWatermarkColumnName]))
            debug(f"  ZORDER cols: {zorder_cols} | stats cols: {stats_cols}")

            spark.sql(f"""
                ALTER TABLE {silver_tbl_q}
                SET TBLPROPERTIES ('delta.dataSkippingStatsColumns' = '{stats_cols}')
            """)
            log("  Successfully updated statistics columns")

            if table_was_created or insert_count >= OPTIMIZE_MIN_INSERTS:
                # Name-based OPTIMIZE for consistency with the ALTER/REFRESH above.
                spark.sql(f"OPTIMIZE {silver_tbl_q} ZORDER BY ({zorder_cols})")
                log("  OPTIMIZE complete.")
            else:
                log(f"  Skipping OPTIMIZE (insert_count {insert_count:,} < {OPTIMIZE_MIN_INSERTS:,}).")

            # Force SQL endpoint metadata refresh
            spark.sql(f"REFRESH TABLE {silver_tbl_q}")

            # ── STEP 11: Mark isDeleted = true for Ids absent from source ──────
            # PERF #4 / FIX #2 – This full-table sweep (NOT MATCHED BY SOURCE)
            # scans the entire Silver table, so it is opt-in via pRunSoftDelete.
            # It is ALSO guarded against an empty/missing active-IDs source: an
            # empty source with NOT MATCHED BY SOURCE would flag EVERY current row
            # as deleted — a catastrophic data event.
            log("STEP 11: (conditional) Marking isDeleted = true for current Ids absent from source")
            active_ids_q = quote_table_name(ACTIVE_IDs_TABLE)

            if not pRunSoftDelete:
                log("  Skipping isDeleted sweep: pRunSoftDelete is False.")
            elif not spark.catalog.tableExists(ACTIVE_IDs_TABLE):
                log(f"  Skipping isDeleted sweep: active-IDs table '{ACTIVE_IDs_TABLE}' not found.", "WARN")
            elif spark.table(active_ids_q).isEmpty():
                # FIX #2 – never sweep against an empty source.
                log(f"  Skipping isDeleted sweep: active-IDs table '{ACTIVE_IDs_TABLE}' is EMPTY (safety guard).", "WARN")
            else:
                merge_condition = " AND ".join([f"TGT.{pk} = SRC.{pk}" for pk in primary_keys])
                sql = f"""
                    MERGE INTO {silver_tbl_q} TGT
                    USING {active_ids_q} SRC
                        ON {merge_condition}
                    WHEN NOT MATCHED BY SOURCE
                         AND TGT.{SCD2_IS_CURRENT_COL} = true
                         AND TGT.{IS_DELETED_COL} IS NOT TRUE THEN
                        UPDATE SET
                            TGT.{IS_DELETED_COL}           = true,
                            TGT.{META_UPDATED_EXEC_ID_COL} = {execution_id}
                """
                debug(f"  SQL for Mark isDeleted:\n{sql}")
                spark.sql(sql)
                log("  isDeleted sweep complete.")

            # ── STEP 12: Silver Watermark (already computed from the batch) ─────
            log(f"STEP 12: Silver Watermark for Pipeline = {silver_watermark}")

        # All paths through the outer else succeeded
        execution_status = "SUCCESS"

    log("=" * 70)
    log(f"Bronze → Silver SCD2 Notebook – COMPLETE | Status: {execution_status}")
    log(f"  Silver table     : {pSilverTableName}")
    log(f"  silver_watermark : {silver_watermark}")
    log(f"  Records read from bronze (post-wm filter): {watermark_filtered_count:,}")
    log(f"  Records after deduplication              : {deduped_count:,}")
    log(f"  Records inserted into Silver             : {insert_count:,}")
    log("=" * 70)

# =============================================================================
# SECTION 7 – ERROR HANDLING  (UNCHANGED)
# =============================================================================

except Exception as exc:
    execution_status = "FAILURE"
    error_msg   = f"FAILURE: {str(exc)}"
    log("=" * 70, "ERROR")
    log("Bronze → Silver SCD2 Notebook – FAILED", "ERROR")
    log(f"Error message : {str(exc)}", "ERROR")
    log("Full traceback:", "ERROR")
    log(traceback.format_exc(), "ERROR")
    log("=" * 70, "ERROR")

finally:
    exit_payload = json.dumps({
        "status"             : execution_status,
        "error_msg"          : error_msg,
        "silverTable"        : pSilverTableName,
        "executionId"        : execution_id,
        "processId"          : process_id,
        "notebookRunDt"      : run_datetime_str,
        "recordsFromBronze"  : watermark_filtered_count,
        "recordsAfterDedup"  : deduped_count,
        "silverWatermark"    : silver_watermark
    })

    log(f"Notebook exit payload: {exit_payload}")
    mssparkutils.notebook.exit(exit_payload)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }
