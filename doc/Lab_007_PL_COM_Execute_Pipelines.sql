--===========================================================================================================================
-- Lab 7 : Azure Data Factory Execute Pipeline Activity
--===========================================================================================================================
1. Link : https://www.mssqltips.com/sqlservertip/6137/azure-data-factory-control-flow-activities-overview/

2. Scenario :
    - The Execute Pipeline activity can be used to invoke another pipeline
    - Similar to SSIS’s Execute Package Task
    - You can use it to create complex data flows, by nesting multi-level pipelines inside each other
    - This activity also allows passing parameter values from parent to child pipeline
    
3. Clone to '006_PL_DATA_StoredProcedure_Param' and add parameter
    - Pipeline parameter : PL_TableName
    
4. 007_PL_COM_Execute_Pipelines
    - Add Execute Pipeline Activity
    - Invoked pipeline : 006_PL_DATA_StoredProcedure_Param
    - PL_TableName : Value from Parent

5. Run or Debug and check table

PipelineName	                    RunId	                                TableName
---------------------------------------------------------------------------------------------
006_PL_DATA_StoredProcedure	        d698ef6e-f097-4b62-9679-3450fc9fa199	DemoTable
006_PL_DATA_StoredProcedure_Param	aefd3910-62c2-42a6-906e-6474c29d4c0b	Value from Parent --> Inserted

--(End)----------------------------------------------------------------------------------------------------------------------
