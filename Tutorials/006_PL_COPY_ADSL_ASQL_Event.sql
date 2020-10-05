--===========================================================================================================================
-- Lab 6 : Event Based Trigger in Azure Data Factory
--===========================================================================================================================
1. Link : https://www.mssqltips.com/sqlservertip/6063/create-event-based-trigger-in-azure-data-factory/

2. Azure Event Grid Setup
    - Azure Portal  -> 
    - Subscription  ->
    - Free Trial    ->
    - Resource provider ->
    - Register 'Microsoft.EventGrid'

3. Create container at datalake
    - datalake  : datalake0318
    - container : salesevent

4. Scenario
    - The pipeline '006_PL_COPY_ADSL_ASQL_Event' should be kicked-off automatically,
        in response to each file drop event and will transfer data related to that specific file.
    - Therefore, in our case we should see three executions, matching the count of CSV files.
    - Make this trigger a bit smarter to initiate each execution with specific parameters,
        indicating which file has caused this execution, so the pipeline transfers data for the related file only.

