--===========================================================================================================================
-- Lab 8 : Azure Data Factory Get Metadata and Save it to DB table
--===========================================================================================================================
1. Link : https://www.mssqltips.com/sqlservertip/6246/azure-data-factory-get-metadata-example/

2. Scenario
    - Read the list of the files available in the source folder
    - Use 'Get Metadata' activity
    - Pass it to conditional activity, to determine if the file has been modified within the last 7 days
    - Copy each recently changed file into the destination database

3. DB table
    - DB : SQL0319
    - Table : FactInternetSales

4. Create a pipeline : 008_PL_COM_Save_Metadata
