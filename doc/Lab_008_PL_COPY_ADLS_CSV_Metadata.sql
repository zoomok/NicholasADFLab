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

4. Create a pipeline : 008_PL_COPY_ADLS_CSV_Metadata

5. Dataset
    - DS_ADLS_CSV_Sales
    - DS_ADLS_CSV_SalesEvent_Param
    - DS_ASQL0319_InternetSales

6. Run or Debug pipeline

7. Check table
-- SQL0319
select	*
from	FactInternetSales
;

--(End)----------------------------------------------------------------------------------------------------------------------
