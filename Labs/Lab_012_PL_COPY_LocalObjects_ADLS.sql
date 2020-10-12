--===========================================================================================================================
-- Lab 12 : Azure Data Factory Pipeline to fully Load all SQL Server Objects to ADLS Gen2 as CSV files
--===========================================================================================================================
1. Link :
	https://www.mssqltips.com/sqlservertip/6302/azure-data-factory-pipeline-to-fully-load-all-sql-server-objects-to-adls-gen2/
	https://www.mssqltips.com/sqlservertip/6350/load-data-lake-files-into-azure-synapse-analytics-using-azure-data-factory/

2. Scenario :  I will demo the process of creating an end-to-end Data Factory pipeline to move
				all on-premises SQL Server objects including databases and tables to Azure Data Lake Storage gen 2
				with a few pipelines that leverage dynamic parameters

3. Create a PipelineParameters database and table in Azure SQL
	- Database	: PipelineParameters
	- Table		: pipeline_parameter
	SQL>
	CREATE TABLE [dbo].[pipeline_parameter](
	   [Table_Name] [nvarchar](500) NULL,
	   [TABLE_CATALOG] [nvarchar](500) NULL,
	   [process_type] [nvarchar](500) NULL
	) ON [PRIMARY]
	GO

4. Create a container and folder
	- Container	: dblake
	- Folder	: rl-sql-001

5. Prepare for 3 Linked Services
	- LS_ADLS					: data lake
	- LS_SQL_Local_Desktop 		: Local DB (AdventureWorks2012)
	- LS_ASQL_Pipeline			: Azure SQL PipelineParameters DB

5. Create 3 datasets
	- DS_ADLS_AdventureWorks_CSV : for AdventureWorks2012 objects to CSV files

		- Linked service		: LS_ADLS
		- Parameters
			- table_name
			- table_catalog_name
		- Directory 		: @concat('dblake/',dataset().table_catalog_name)
		- File				: @{item().Table_Name}/@{formatDateTime(utcnow(),'yyyy')}/@{formatDateTime(utcnow(),'MM')}/
							  @{formatDateTime(utcnow(),'dd')}/@{item().Table_Name}@{formatDateTime(utcnow(),'HH')}

	- DS_SQL_Desktop		: for Local desktop objects
		- Linked service	: LS_SQL_Local_Desktop
		- Tables			: None

	- DS_ASQL_Pipeline_Param : for PipelineParameters.pipeline_parameter table
		- Linked service	: LS_SQL_Local_Desktop 
		- Table				: dbo.pipeline_parameter

6. Create a pipeline
	- Name		: 012_PL_COPY_LocalObjects_ADLS
	- Add Copy activity
		- Source
			- Dataset	: DS_SQL_Desktop
			- Query		:
			SQL>
			select	quotename(table_schema) + '.' +
					quotename(table_name) as Table_Name,
					Table_catalog
			from	information_schema.tables

		- Sink
			- Dataset	: DS_ASQL_Pipeline_Param
			- Pre-copy 	: truncate table pipeline_parameter

	
	- Add Lookup activity
		- Dataset	: DS_ASQL_Pipeline_Param
		
	- Add Foreach activity
		- Items		: @activity('Get-Tables').output.value
		
		- Add Copy activity
			- Source
				- Dataset	: DS_SQL_Desktop
				- Query		: use @{item().Table_Catalog} select * from @{item().Table_Name}
			- Sink
				- Dataset	: DS_ADLS_AdventureWorks_CSV
				- table_name			: @{item().Table_Name}
				- table_catalog_name 	: @{item().Table_Catalog}

--(End)----------------------------------------------------------------------------------------------------------------------
