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

# CELL ********************

# MAGIC %%sql
# MAGIC /*drop table if exists Kantata.HISTORY_ActivityAssignment
# MAGIC drop table if exists Kantata.HISTORY_ResourcedActivity 
# MAGIC drop table if exists Kantata.HISTORY_ActivityAssignmentDemand */
# MAGIC drop table if exists Kantata.HISTORY_Resource


# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark"
# META }
