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
# This cell is tagged "parameters" so the pipeline / variable library can override the values below.

# Pipeline parameter
ApiPublisher = "CrederaLtd"

# Business Central (vl_Bc365 / vl_SrcBc365 library variables)
Bc365TenantId     = ""   # vl_SrcBc365_Bc365TenantId
Bc365ClientId     = ""   # vl_Bc365_Bc365ClientId
Bc365Sc           = ""   # vl_Bc365_Bc365Sc  (client S — prefer a Key Vault-backed value)
Bc365EnvName      = "Sandbox"   # vl_Bc365_Bc365EnvName

# Preferred: retrieve the client secret from Key Vault instead of passing it in plain text.
# KeyVaultUrl       = "https://<your-vault>.vault.azure.net/"
# Bc365ProdSecName  = "Bc365ProdSec"   # secret name in Key Vault
# Bc365Sc      = mssparkutils.credentials.getSecret(KeyVaultUrl, Bc365ProdSecName)

# Fabric SQL Database target (resolved from vl_FabricObjects_* in the pipeline)
SqlServer= "26wb2mhrmc7ufbgouobam4lram-h4i7qkmqfipebjhx2yjbwsaude.database.fabric.microsoft.com"
SqlDatabase= "FabricDb"

# Endpoints
AadAuthorityBase = "https://login.microsoftonline.com"
Bc365ApiBase     = "https://api.businesscentral.dynamics.com/v2.0"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import struct
import time
import requests
import pyodbc

# Transient Fabric SQL errors worth retrying (DB resuming / mid system-update).
_TRANSIENT_SQLSTATES = {"28000", "08001", "08S01", "40001", "HYT00"}
_CONNECT_MAX_ATTEMPTS = 5
_CONNECT_BACKOFF_SECONDS = 5


def _open_connection():
    """Single connection attempt using a freshly-minted Entra access token."""
    raw_token = mssparkutils.credentials.getToken("https://database.windows.net/")
    token_bytes = raw_token.encode("utf-16-le")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

    conn_str = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={SqlServer},1433;"
        f"Database={SqlDatabase};"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        "Connection Timeout=30;"
    )
    SQL_COPT_SS_ACCESS_TOKEN = 1256
    conn = pyodbc.connect(conn_str, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct})
    conn.autocommit = True
    return conn


def get_db_connection():
    """
    Connects to Fabric SQL Database using a Microsoft Entra ID access token from the
    current Fabric session identity. Retries transient failures (e.g. 18456 / "system
    update" thrown while the database is resuming) with a fresh token each attempt.
    """
    last_error = None
    for attempt in range(1, _CONNECT_MAX_ATTEMPTS + 1):
        try:
            return _open_connection()
        except pyodbc.Error as exc:
            sqlstate = exc.args[0] if exc.args else None
            if sqlstate not in _TRANSIENT_SQLSTATES or attempt == _CONNECT_MAX_ATTEMPTS:
                raise
            last_error = exc
            wait = _CONNECT_BACKOFF_SECONDS * attempt
            print(f"  Transient connection error ({sqlstate}); retry {attempt}/{_CONNECT_MAX_ATTEMPTS - 1} in {wait}s...")
            time.sleep(wait)
    raise last_error

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def get_bc365_token():
    """Client-credentials token request against Entra ID for the Business Central API."""
    url = f"{AadAuthorityBase}/{Bc365TenantId}/oauth2/v2.0/token"
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    # requests url-encodes the form body (handles the secret like encodeUriComponent in the pipeline).
    data = {
        "grant_type": "client_credentials",
        "scope": "https://api.businesscentral.dynamics.com/.default",
        "client_id": Bc365ClientId,
        "client_secret": Bc365Sc,
    }
    resp = requests.post(url, headers=headers, data=data, timeout=600)
    resp.raise_for_status()
    return resp.json()["access_token"]


access_token = get_bc365_token()
print("Acquired Business Central access token.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def get_api_groups():
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("TRUNCATE TABLE ETL.Bc365ColumnMetadataRaw;")
        cur.execute("SELECT S.ApiGroup FROM ETL.BcSourceConfig S GROUP BY S.ApiGroup;")
        return [row[0] for row in cur.fetchall()]
    finally:
        conn.close()


api_groups = get_api_groups()
print(f"Found {len(api_groups)} API group(s): {api_groups}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def get_api_metadata(api_group, token):
    """GET the OData $metadata document (XML) for a single API group."""
    url = (
        f"{Bc365ApiBase}/{Bc365TenantId}/{Bc365EnvName}"
        f"/api/{ApiPublisher}/{api_group}/v2.0/$metadata"
    )
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    resp = requests.get(url, headers=headers, timeout=1800)
    resp.raise_for_status()
    return resp.text


INSERT_RAW_SQL = """
INSERT INTO ETL.Bc365ColumnMetadataRaw (MetadataXML, ApiPublisher, ApiGroup, ApiVersion)
VALUES (?, ?, ?, ?);
"""

conn = get_db_connection()
try:
    cur = conn.cursor()
    for api_group in api_groups:
        print(f"Fetching metadata for ApiGroup='{api_group}'...")
        metadata_xml = get_api_metadata(api_group, access_token)
        cur.execute(INSERT_RAW_SQL, metadata_xml, ApiPublisher, api_group, "v2.0")
        print(f"  Staged {len(metadata_xml):,} chars of XML.")
finally:
    conn.close()

print("All API groups staged.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

SHRED_SQL = r"""
TRUNCATE TABLE ETL.Bc365ColumnMetadata;

WITH XMLNAMESPACES
(
    'http://docs.oasis-open.org/odata/ns/edm' AS edm
),

EntityProperties AS
(
    SELECT
          R.ApiPublisher
        , R.ApiGroup
        , E.value('@Name','varchar(255)') AS EntityName
        , P.value('@Name','varchar(255)') AS ColumnName
        , REPLACE(P.value('@Type','varchar(255)'), 'Edm.', '') AS DataType
        , CAST
          (
              CASE
                  WHEN P.value('@Nullable','varchar(10)') = 'false'
                  THEN 0
                  ELSE 1
              END
              AS bit
          ) AS IsNullable
    FROM    ETL.Bc365ColumnMetadataRaw R
    CROSS APPLY R.MetadataXML.nodes('//edm:EntityType') T(E)
    CROSS APPLY E.nodes('edm:Property') X(P)
),

EntityKeys AS
(
    SELECT
          R.ApiPublisher
        , R.ApiGroup
        , E.value('@Name','varchar(255)') AS EntityName
        , K.value('@Name','varchar(255)') AS ColumnName
    FROM ETL.Bc365ColumnMetadataRaw R
    CROSS APPLY R.MetadataXML.nodes('//edm:EntityType') T(E)
    CROSS APPLY E.nodes('edm:Key/edm:PropertyRef') X(K)
),

EntitySets AS
(
    SELECT
          R.ApiPublisher
        , R.ApiGroup
        , ES.value('@Name','varchar(255)') AS ApiEntitySetName
        , RIGHT
          (
              ES.value('@EntityType','varchar(500)'),
              CHARINDEX
              (
                  '.',
                  REVERSE(ES.value('@EntityType','varchar(500)'))
              ) - 1
          ) AS EntityName
    FROM ETL.Bc365ColumnMetadataRaw R
    CROSS APPLY R.MetadataXML.nodes('//edm:EntitySet') X(ES)
)
INSERT INTO ETL.Bc365ColumnMetadata
(
    ApiPublisher ,
    ApiGroup ,
    EntityName ,
    ApiEntitySetName ,
    ColumnName ,
    DataType ,
    IsNullable ,
    IsKeyColumn
)
SELECT
      P.ApiPublisher
    , P.ApiGroup
    , P.EntityName
    , S.ApiEntitySetName
    , P.ColumnName
    , P.DataType
    , P.IsNullable
    , CAST
      (
          CASE
              WHEN K.ColumnName IS NULL THEN 0
              ELSE 1
          END
          AS bit
      ) AS IsKeyColumn
FROM EntityProperties P
LEFT JOIN EntitySets S
       ON  S.ApiPublisher  = P.ApiPublisher
       AND S.ApiGroup   = P.ApiGroup
       AND S.EntityName = P.EntityName
LEFT JOIN EntityKeys K
       ON  K.ApiPublisher  = P.ApiPublisher
       AND K.ApiGroup   = P.ApiGroup
       AND K.EntityName = P.EntityName
       AND K.ColumnName = P.ColumnName
ORDER BY P.ApiGroup, S.ApiEntitySetName, P.ColumnName;
"""

conn = get_db_connection()
try:
    cur = conn.cursor()
    cur.execute(SHRED_SQL)
finally:
    conn.close()

print("Shred complete — ETL.Bc365ColumnMetadata repopulated.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
