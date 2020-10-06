--#################################################################################################################################################################
--#################################################################################################################################################################
--1. Azure Data Factory					###########################################################################################################
--#################################################################################################################################################################
--#################################################################################################################################################################
--===========================================================================================================================
-- Lab 1 : Create Linked Services
--===========================================================================================================================
--===========================================================================================================================
-- Lab 2 : Event Based Trigger in Azure Data Factory
--===========================================================================================================================
1. Enable Trigger
	* Subscription 	-> Resource providers
	* Microsoft.EventGrid : Registered

2. Create Trigger
	* Data Factory portal -> Manage (4th Tab) -> New
		- Name 			: MyFileEventTrigger
		- Storage account name 	: datalake0318
		- Container name 	: csvfiles
		- Blob path ends with 	: .csv

3. Datasets
	* DS_ADLS_InternetSales_Param
		- Linked service	: LS_ADLS_0318
		- Parameters
			- Name		: FileName
			- Type		: String
			- Default value	: @pipeline().parameters.SourceFile
		- File path		: csvfiles/(blank)/@dataset.FileName
		- First row as header : Checked

	* DS_SQL_FactInternetSales
		- Linked service	: LS_SQL_0319
		- Table			: FactInternetSales

	* DS_SQL_DimCurrency
		- Linked service	: LS_SQL_0319
		- Table			: DimCurrency

4. Create Pipeline
	* PL_DATA_ADLS_to_DS_FactInternetSales_Event
		- Parameters
			- Name		: SourceFile
			- Type		: String
	* Add If Condition Activity
		- Activities		: @bool(startswith(pipeline().parameters.SourceFile,'FactInternetSales'))
		- True
			- Add Copy data activity
			- Source
				- dataset	: DS_ADLS_InternetSales_Param
				- FileName	: @pipeline.parameters.SourceFile
				- Wildcard paths : csvfiles/blank/`*.csv`
			- Sink
				- dataset	: DS_SQL_FactInternetSales
				- pre-copy	: truncate table FactInternetSales
		- False
			- Add Copy data activity
			- Source
				- dataset	: DS_ADLS_InternetSales_Param
				- FileName	: @pipeline.parameters.SourceFile
			- Sink
				- dataset	: DS_SQL_DimCurrency
				- pre-copy	: truncate table DimCurrency

5. Run
	* Edit Trigger
	* Select `MyFileEventTrigger`

--===========================================================================================================================
-- Lab 3 : Copy multiple tables using Filter
--===========================================================================================================================
1. Create view and stored procedure
-- 0318 DB
use SQL0318
Go
CREATE VIEW VW_TableList_P
AS
SELECT 	TABLE_SCHEMA as sch,
		TABLE_NAME as tbl
FROM 	INFORMATION_SCHEMA.TABLES 
WHERE 	TABLE_TYPE = 'BASE TABLE'
;

-- 0319 DB
CREATE PROCEDURE [dbo].[Usp_PurgeTargetTables]
AS
BEGIN
delete from [SalesLT].[Product]
delete from [SalesLT].[ProductModelProductDescription]
delete from [SalesLT].[ProductDescription]
delete from [SalesLT].[ProductModel]
delete from [SalesLT].[ProductCategory]
END
;

2. Datasets
	* DS_ASQL_VW_TableList_P
		- Linked service 	: LS_SQL_0318
		- Table 		: dbo.VW_TableList_P

	* DS_ASQL_0318_Table_Param
		- Linked service	: LS_SQL_0318
		- Parameter
			- SchemaName / String
			- TableName  / String
		- Table : @dataset().SchemaName / @dataset().TableName

	* DS_ASQL_0319_Table_Param
		- Linked service	: LS_SQL_0319
		- Parameter
			- schema / String
			- table  / String
		- Table : @dataset().schema / @dataset().table

3. Create pipeline
	* PL_DATA_ASQL_ForEach

	* Add Lookup activity
		- dataset	: DS_ASQL_VW_TableList_P
	
	* Add Filter activity
		- Items		: @activity('Lookup1').output.value
		- Condition	: @startswith(string(item().tbl),'P') --> `tbl` from view column name

	* Add Strored procedure activity
		- Linked service	: LS_SQL_0319
		- Stored procedure name	: Usp_PurgeTargetTables

	* Add ForEach activity
		- Items		: @activity('Filter1').output.value
		- Activity
			* Add Copy activity
			- Source
				dataset		: DS_ASQL_0318_Table_Param
				SchemaName 	: @item().sch
				TableName	: @item().tbl
			- Sink
				dataset		: DS_ASQL_0319_Table_Param
				schema		: @item().sch
				table		: @item().tbl

4. Run
	* Trigger now
	* Check 0319 tables

--===========================================================================================================================
-- Lab 4 : Incremental Data Load
--===========================================================================================================================
1. Scenario (Source -> Staging)
* 1st day 1,000 -> 1,000
* 2nd day 100 inserted records
           50 updated records
* LastUpdatedDate, CreatedDate (yyyymmdd hh:mm:ss)

* A single pipeline which can load dynamically multiple tables as we want
* Config Table
	- Table Name 		: List of tables that we want to load in staging (80 tables)
	- DataSource		: OracleERP
	- Max_LastUpdateDate 	: MAX(LastUpdatedDate) in staging table (15th May as of 17th May)
	- Enabled		: Flag for tables to load (1 : Enabled, 0 : Disabled)
	- Incremental_Fullload 	: (1 : Incremental, 0 : Full load)

* (17/05) -> 15th May 2020
* (18/05) -> Insert into staging table
			 select * from OracleERP.tablename
			 where lastupdateDate > MAX_LastUpdateDate(15th May 2020)

2. Data preparation
-- SQL0318
create table Lead
(
Lead_Name 	varchar(max),
Campaign 	varchar(max),
Product 	varchar(max),
Last_Updated_Date datetime
)
;

create table Customer
(
Customer_Name	varchar(max),
Address 		varchar(max),
City 			varchar(max),
Last_Updated_Date datetime
)
;

create table Users
(
User_Name	varchar(100),
Address		varchar(200),
Last_Updated_Date datetime
)
;

-- SQLStaging
create table cfg
(
Table_Name 	varchar(max),
Source 		varchar(max),
Max_LastUpdatedDate datetime,
Enabled 	int,
Incremental_Full_Load int
)
;

create table Lead
(
Lead_Name 	varchar(max),
Campaign 	varchar(max),
Product 	varchar(max),
Last_Updated_Date datetime
)
;

create table Customer
(
Customer_Name	varchar(max),
Address 		varchar(max),
City 			varchar(max),
Last_Updated_Date datetime
)
;

3. Datasets
	* DS_ASQL_0318_SRC_Tables
		- Linked service	: LS_SQL_0318
		- Table			: Customer

	* DS_ASQL_Staging_CFG
		- Linked service 	: LS_SQL_Staging
		- Table 		: cfg

	* DS_ASQL_Staging_Tables
		- Linked service	: LS_SQL_Staging
		- Parameters		: Table
		- Table			: dbo.@dataset().TableName

4. Create Pipeline
	* PL_DATA_ASQL_IncrDataLoad
	
	* Add Lookup activity : Lookup Enabled
		- dataset 	: DS_ASQL_Staging_CFG
		- Query		: select * from cfg where Enabled = 1	--> Load Enabled
		- First row only : Unchecked

	* Add Filter activity : Filter CRM
		- Items		: @activity('Lookup Enabled').output.value
		- Condition	: @equals(item().Source,'CRM')			--> Filter for 'CRM'
	
	* Add ForEach activity : ForEach Data Load
		- Sequential : Checked
		- Items		: @activity('Filter1').output.value
	
		* Add If Condition activity
			- Expression	: @bool(equals(item().Incremental_Full_Load,1)) --> Incremental or Full load

			- True	--> Incremental load
				* Add Lookup activity : Get Max LastUpdateDate from CFG
					- Query	: 	select	max_lastupdateddate
							from	cfg
							where	table_name = '@{item().Table_Name}'

				* Add Copy activity : Copy SRC to STG Incremental
					- Source
					- dataset 	: DS_ASQL_0318_Customer
					- Query		:
							select  *
							from @{item().Table_Name}
							where convert(varchar(max), last_updated_date, 120) >
							convert(varchar(max), substring(replace('@{activity('Get Max UpdateDate from CFG').
							output.firstrow.max_lastupdateddate}', 'T', ' '), 0, 20), 120)
					- Sink
					- dataset	: DS_ASQL_Staging_Tables
					- Table		: @{item().Table_Name}

				* Add Lookup activity : Get Max Update
					- Source
					- dataset	: DS_ASQL_Staging_Tables
					- Table		: @{item().Table_Name}
					- Query		:
							select  max(Last_Updated_Date) as maxD
							from	@{item().Table_Name}
					- First row only : Checked
				
				* Add Lookup activity : Update max last update date in CFG
					- Source
					- dataset	: DS_ASQL_Staging_CFG
					- Query		:
							update 	CFG
							set 	max_lastupdateddate = '@{activity('Get Max Update').output.firstRow.maxD}'
							where	table_name like '@{item().Table_Name}'
							select	'1'
					- First row only : Checked

			- False	--> Full load
				* Add Copy activity : Copy SRC to STG Full Load
					- Source
					- dataset	: DS_ASQL_0318_Customer
					- Query		:
							select	*
							from	@{item().Table_Name}
					- Sink
					- dataset	: DS_ASQL_Staging_Tables
					- Table		: @{item().Table_Name}
				
				* Add Lookup activity : Get Max Update date from Staging
					- Source
					- dataset	: DS_ASQL_Staging_Tables
					- Table		: @{item().Table_Name}
					- Query		:
							select	max(last_updated_date) as maxD
							from	@{item().Table_Name}
					- Firstt row only : Checked
				
				* Add Lookup activity : Update CFG table
					- dataset	: DS_ASQL_Staging_CFG
					- Query		:
							update 	CFG
							set		Max_LastUpdatedDate = 
							'@{activity('Get Max Update date from Staging').output.firstRow.maxD}'
							where	table_name like '@{item().Table_Name}'
							select	'1'
					- First row only : Checked

5. Test

--------------------------------------------------------------------------------------
-- (Full load)
--------------------------------------------------------------------------------------
-- Current date : (2020-09-13 11:10:11.000)
-- SQL0318
truncate table customer;
truncate table lead;
truncate table users;

insert into Lead values('John', 'EmailCampaign', 'Hydrolics', getdate()-10); 		--> (2020-09-03)
insert into Lead values('Mike', 'SMSCampaign', 'Crane', getdate()-10);			--> (2020-09-03)

insert into Customer values('John Deere', '345 W MAdison St', 'Chicago', getdate()-11);	--> (2020-09-02)
insert into Customer values('Citibank', '985 W Jackson St', 'New York', getdate()-11);	--> (2020-09-02)

insert into Users values('Nicholas', '46 Crown Point Ridge', getdate()-12);		--> (2020-09-01)
insert into Users values('Sunny', '22 Capricorn Ave', getdate()-12);			--> (2020-09-01)

-- STG
truncate table cfg;
truncate table customer;
truncate table lead;
truncate table users;

insert into cfg values('Lead', 'CRM', getdate()-20, 1, 0);		--> (2020-08-24)
insert into cfg values('Customer', 'CRM', getdate()-20, 1, 0);		--> (2020-08-24)
insert into cfg values('Users', 'CRM', getdate()-20, 1, 0);		--> (2020-08-24)

-- Before run
-- cfg
Table_Name	Source	Max_LastUpdatedDate			Enabled	Incremental_Full_Load
----------- ------- --------------------------- ------- -----------------------
Lead		CRM		2020-08-24 11:10:12.200		1		0
Customer	CRM		2020-08-24 11:10:12.220		1		0
Users		CRM		2020-08-24 11:10:12.227		1		0

-- After run
Table_Name	Source	Max_LastUpdatedDate			Enabled	Incremental_Full_Load
----------- ------- --------------------------- ------- -----------------------
Lead		CRM		2020-09-03 11:09:51.757		1		0
Customer	CRM		2020-09-02 11:09:53.627		1		0
Users		CRM		2020-09-01 11:09:55.160		1		0

--------------------------------------------------------------------------------------
-- (Incremental load)
--------------------------------------------------------------------------------------
-- SQL0318
insert into Lead values('Lead1','EBS','Hydrolics', getdate()-9);		--> (2020-09-04)
insert into Lead values('Lead2','BR','Crane', getdate()-9);			--> (2020-09-04)
insert into Lead values('Lead3','BR','Crane', getdate()-5);			--> (2020-09-08)

insert into Customer values('Customer1', '345 W MAdison St', 'Chicago', getdate()-8);	--> (2020-09-05)
insert into Customer values('Customer2', '985 W Jackson St', 'New York', getdate()-8);	--> (2020-09-05)
insert into Customer values('Customer3', '985 W Jackson St', 'New York', getdate()-5);	--> (2020-09-08)

insert into Users values('Users1', '46 Crown Point Ridge', getdate()-7);	--> (2020-09-06)
insert into Users values('Users2', '22 Capricorn Ave', getdate()-7);		--> (2020-09-06)
insert into Users values('Users3', '22 Capricorn Ave', getdate()-5);		--> (2020-09-08)

-- STG
update 	cfg
set		Incremental_Full_Load = 1
;

-- Before run
Table_Name	Source	Max_LastUpdatedDate			Enabled	Incremental_Full_Load
----------- ------- --------------------------- ------- -----------------------
Lead		CRM		2020-09-03 11:09:51.757		1		1
Customer	CRM		2020-09-02 11:09:53.627		1		1
Users		CRM		2020-09-01 11:09:55.160		1		1

-- After run
Table_Name	Source	Max_LastUpdatedDate			Enabled	Incremental_Full_Load
----------- ------- --------------------------- ------- -----------------------
Lead		CRM		2020-09-08 11:25:44.157		1		1
Customer	CRM		2020-09-08 11:25:46.470		1		1
Users		CRM		2020-09-08 11:25:48.327		1		1

select	*
from	Lead
;
Lead_Name	Campaign		Product		Last_Updated_Date
----------- --------------- ----------- -----------------------
John		EmailCampaign	Hydrolics	2020-09-03 11:09:51.747
Mike		SMSCampaign		Crane		2020-09-03 11:09:51.757
Lead1		EBS				Hydrolics	2020-09-04 11:25:44.127
Lead2		BR				Crane		2020-09-04 11:25:44.150
Lead3		BR				Crane		2020-09-08 11:25:44.157

select	*
from	Customer
;
Customer_Name	Address				City		Last_Updated_Date
--------------- ------------------- ----------- -----------------------
John Deere		345 W MAdison St	Chicago		2020-09-02 11:09:53.620
Citibank		985 W Jackson St	New York	2020-09-02 11:09:53.627
Customer1		345 W MAdison St	Chicago		2020-09-05 11:25:46.453
Customer2		985 W Jackson St	New York	2020-09-05 11:25:46.460
Customer3		985 W Jackson St	New York	2020-09-08 11:25:46.470

select	*
from	Users
;
User_Name	Address					Last_Updated_Date
----------- ----------------------- -----------------------
Nicholas	46 Crown Point Ridge	2020-09-01 11:09:55.150
Sunny		22 Capricorn Ave		2020-09-01 11:09:55.160
Users1		46 Crown Point Ridge	2020-09-06 11:25:48.313
Users2		22 Capricorn Ave		2020-09-06 11:25:48.320
Users3		22 Capricorn Ave		2020-09-08 11:25:48.327

--===========================================================================================================================
-- Lab 5 : Data Flow
--===========================================================================================================================
1. Scenario
* Get Chicago crime data from https://data.cityofchicago.org/resource/crimes.json?$limit=50000
* Copy data to data lake as csv file
* From csv file, extract DayOfWeekCount and save aggregation data to Azure database

2. Linked service
	- Name					: ChicagoCrime
	- Base URL				: https://data.cityofchicago.org/resource/crimes.json?$limit=50000
	- Type					: HTTP
	- Authentication type	: Anonymous

3. Datasets
	* SODACrimeAPI
		- Linked service 	: ChicagoCrime
		- Data type		: Json

	* ChicagoCrimeFile
		- Linked service	: LS_ADLS_0318
		- File path		: demo / (blank) / ChicagoCrime.csv
		- First row header	: Checked

	* DS_ASQL_CrimeData
		- Linked service	: LS_SQL_0319
		- Table			: (blank).CrimeData202009

3. Create pipeline
	* CrimeDataPipe

	* Add Copy data activity
		- Source
		- dataset	: SODACrimeAPI
		- method	: GET
		
		- Sink
		- dataset	: ChicagoCrimeFile

	* Add Data flow activity
		- Source	: "CrimeDataFile"
		- type		: Dataset
		- dataset	: ChicagoCrimeFile
		
		- Derived column : "ExtractDateTime"
		- Incoming	: CrimeDataFile
		- Columns
			- Date	: left(date,10)
			- Time	: right(date, 8)
		
		- Aggregation	: "DayOfWeekCount"
		- Incoming	: ExtractDateTime
		- Columns
			- dayOfWeek(toDate(ExtractDateTime@Date, 'yyyy-mm-dd'))
			- DayOfWeek


		- Branch	: "ExtractDateTime"
		- Incoming	: CrimeDataFile
		
		- Filter	: "Only202009"
		- Incoming	: ExtractDateTime
		- Filter on	: left(ExtractDateTimeBR@Date, 7)=='2020-09'
		
		- Sink		: "CopyCrimeData"
		- Incoming	: Only202009
		- Sink Type	: Dataset
		- dataset	: DS_ASQL_CrimeData
		- Mapping	: Disable Auto mapping

4. Run
	* Trigger now
	* Check "ChicagoCrimes.csv" file
	* Check 0319 tables

--===========================================================================================================================
-- Lab 6 : 4 Different ways to work with Azure Data Factory
--===========================================================================================================================
Link : https://docs.microsoft.com/en-us/azure/data-factory/

1. Azure Portal UI
2. Azure PowerShell (Install Azure PowerShell)
3. .NET
4. Python
5. REST
6. Resource Manager Template (Azure PowerShell Az Module) : ARM, JSON file

--===========================================================================================================================
-- Lab 7 : Create ADF using PowerShell
--===========================================================================================================================
----------------------------------------------------------------------------------------------------------------
-- 003. SQL Server (nicholassqlserver)
----------------------------------------------------------------------------------------------------------------
	NicholasSRC : serveradmin / Dkagh0318
	NicholasSTG : serveradmin / Dkagh0318
	NicholasEDW : serveradmin / Dkagh0318

----------------------------------------------------------------------------------------------------------------
-- 004. Power Shell to install
----------------------------------------------------------------------------------------------------------------
Install-Module PowerShellGet -force
Install-Module -Name AzureRM -AllowClobber

----------------------------------------------------------------------------------------------------------------
-- 005. Connect Azure
----------------------------------------------------------------------------------------------------------------
Connect-AzAccount

Account                SubscriptionName TenantId                             Environment
-------                ---------------- --------                             -----------
myorangebox8@gmail.com Free Trial       21c8182a-17d4-4701-b5ec-19bf1b738887 AzureCloud 

----------------------------------------------------------------------------------------------------------------
-- 006. Resource Group
----------------------------------------------------------------------------------------------------------------
$resourceGroupName = "ADFQuickStartRG";
$ResGrp = New-AzResourceGroup $resourceGroupName -location 'East US';
PS C:\Users\Administrator> get-azresourcegroup

ResourceGroupName : NickRG
Location          : eastus
ProvisioningState : Succeeded
Tags              :
ResourceId        : /subscriptions/37920113-f320-43ac-9218-6626692343e7/resourceGroups/NickRG

ResourceGroupName : ADFQuickStartRG
Location          : eastus
ProvisioningState : Succeeded
Tags              :
ResourceId        : /subscriptions/37920113-f320-43ac-9218-6626692343e7/resourceGroups/ADFQuickStartRG

ResourceGroupName : cloud-shell-storage-southeastasia
Location          : southeastasia
ProvisioningState : Succeeded
Tags              :
ResourceId        : /subscriptions/37920113-f320-43ac-9218-6626692343e7/resourceGroups/cloud-shell-storage-southeastasia

$dataFactoryName = "NicholasADFQuickStartFactory";
$DataFactory = Set-AzDataFactoryV2 -ResourceGroupName "ADFQuickStartRG" -Location "East US" -Name "NicholasADFQuickStartFactory";
PS C:\Users\Administrator> Get-AzDataFactoryV2

DataFactoryName   : NicholasADFTutorialDataFactory
DataFactoryId     : /subscriptions/37920113-f320-43ac-9218-6626692343e7/resourceGroups/nickrg/providers/Microsoft.DataF
                    actory/factories/nicholasadftutorialdatafactory
ResourceGroupName : nickrg
Location          : eastus
Tags              : {}
Identity          : Microsoft.Azure.Management.DataFactory.Models.FactoryIdentity
ProvisioningState : Succeeded
RepoConfiguration :
GlobalParameters  :

DataFactoryName   : NicholasADFQuickStartFactory
DataFactoryId     : /subscriptions/37920113-f320-43ac-9218-6626692343e7/resourceGroups/adfquickstartrg/providers/Micros
                    oft.DataFactory/factories/nicholasadfquickstartfactory
ResourceGroupName : adfquickstartrg
Location          : East US
Tags              : {}
Identity          : Microsoft.Azure.Management.DataFactory.Models.FactoryIdentity
ProvisioningState : Succeeded
RepoConfiguration :
GlobalParameters  :

----------------------------------------------------------------------------------------------------------------
-- 007. Create Storage Account
----------------------------------------------------------------------------------------------------------------
-- Blob
Storage account name 	: nicholasblogstorage
Account Kind 		: BlogStorage
Location 		: East US
Subscription 		: Free Trial

-- V2
Storage account name 	: nicholasdatalakev2
Account Kind 		: Storage V2
Location 		: East US
Subscription 		: Free Trial
Hierarchy namespace	: Enabled

----------------------------------------------------------------------------------------------------------------
-- 008. Create Linked Service
----------------------------------------------------------------------------------------------------------------
PS C:\Users\Administrator> Set-Location 'C:\ADFv2QuickStartPSH'

-- Save file to AzureStorageLinkedService.json
-- blog storge
{
	"name": "AzureStorageLinkedService",
	"properties": {
	"annotations": [],
	"type": "AzureBlobStorage",
	"typeProperties": {
	"connectionString": "DefaultEndpointsProtocol=https;AccountName=nicholasblogstorage;AccountKey=ffdS0qu345MQOrE7AFqzwr
				Vjpx9YMh0GyzwkaefOmtLyR6ZTS8qZxkc6CE2BOVGD2KhqNyp7QrwzAVg6HxDuYQ==;EndpointSuffix=core.windows.net"
		}
	}
}

Set-AzDataFactoryV2LinkedService -DataFactoryName "NicholasADFQuickStartFactory" `
-ResourceGroupName "ADFQuickStartRG" -Name "AzureStorageLinkedService" `
-DefinitionFile ".\AzureStorageLinkedService.json"

-- Save file to AzureStorageLinkedServiceV2.json
-- blog storge v2 (datalake)
{
	"name": "AzureStorageLinkedService",
	"properties": {
	"annotations": [],
	"type": "AzureBlobStorage",
	"typeProperties": {
	"connectionString": "DefaultEndpointsProtocol=https;AccountName=nicholasdatalakev2;AccountKey=Vo8RiOuCwjqqm/dR9HbwqGA4k/g
				GrnQ2GbwrxFpx1Y3HaQPCzAXsTR28yRcfohjrga5wGODroHZGwAzuazaR5Q==;EndpointSuffix=core.windows.net"
		}
	}
}

Set-AzDataFactoryV2LinkedService -DataFactoryName "NicholasADFQuickStartFactory" `
-ResourceGroupName "ADFQuickStartRG" -Name "AzureStorageLinkedServiceV2" `
-DefinitionFile ".\AzureStorageLinkedServiceV2.json"

----------------------------------------------------------------------------------------------------------------
-- 009. Create datasets
----------------------------------------------------------------------------------------------------------------
-- InputDataset.json
{
	"name": "InputDataset",
	"properties": {
		"linkedServiceName": {
			"referenceName": "AzureStorageLinkedServiceV2",
			"type": "LinkedServiceReference"
			},
	"annotations": [],
	"type": "Binary",
	"typeProperties": {
		"location": {
			"type": "AzureBlobStorageLocation",
			"fileName": "emp.txt",
			"folderPath": "input",
			"container": "adftutorial"
			}
		}
	}
}

Set-AZDataFactoryV2Dataset -DataFactoryName "NicholasADFQuickStartFactory" `
-ResourceGroupName "ADFQuickStartRG" -Name "InputDataset" `
-DefinitionFile ".\InputDataset.json"

-- or
-- Variable
$DataFactoryName = "NicholasADFQuickStartFactory"
$resourceGroupName = "ADFQuickStartRG";

Set-AzDataFactoryV2Dataset -DataFactoryName $DataFactoryName `
-ResourceGroupName $ResGrp.ResourceGroupName -Name "InputDataset" `
-DefinitionFile ".\InputDataset.json"

-- OutputDataset.json
{
	"name": "OutputDataset",
	"properties": {
		"linkedServiceName": {
			"referenceName": "AzureStorageLinkedServiceV2",
			"type": "LinkedServiceReference"
			},
	"annotations": [],
	"type": "Binary",
	"typeProperties": {
		"location": {
			"type": "AzureBlobStorageLocation",
			"folderPath": "output",
			"container": "adftutorial"
			}
		}
	}
}

Set-AzDataFactoryV2Dataset -DataFactoryName $DataFactoryName `
-ResourceGroupName $ResGrp.ResourceGroupName -Name "OutputDataset" `
-DefinitionFile ".\OutputDataset.json"

----------------------------------------------------------------------------------------------------------------
-- 010. Create a pipeline
----------------------------------------------------------------------------------------------------------------
{
   "name":"Adfv2QuickStartPipeline",
   "properties":{
      "activities":[
         {
            "name":"CopyFromBlobToBlob",
            "type":"Copy",
            "dependsOn":[

            ],
            "policy":{
               "timeout":"7.00:00:00",
               "retry":0,
               "retryIntervalInSeconds":30,
               "secureOutput":false,
               "secureInput":false
            },
            "userProperties":[

            ],
            "typeProperties":{
               "source":{
                  "type":"BinarySource",
                  "storeSettings":{
                     "type":"AzureBlobStorageReadSettings",
                     "recursive":true
                  }
               },
               "sink":{
                  "type":"BinarySink",
                  "storeSettings":{
                     "type":"AzureBlobStorageWriteSettings"
                  }
               },
               "enableStaging":false
            },
            "inputs":[
               {
                  "referenceName":"InputDataset",
                  "type":"DatasetReference"
               }
            ],
            "outputs":[
               {
                  "referenceName":"OutputDataset",
                  "type":"DatasetReference"
               }
            ]
         }
      ],
      "annotations":[

      ]
   }
}

-- Create
$DFPipeLine = Set-AzDataFactoryV2Pipeline `
-DataFactoryName $DataFactoryName `
-ResourceGroupName $ResGrp.ResourceGroupName `
-Name "Adfv2QuickStartPipeline" `
-DefinitionFile ".\Adfv2QuickStartPipeline.json"

-- Run
$RunId = Invoke-AzDataFactoryV2Pipeline `
-DataFactoryName $Datafactoryname `
-ResourceGroupName $ResGrp.ResourceGroupName `
-PipelineName $DFPipeLine.Name

-- Monitor
while ($True) {
	$Run = Get-AzDataFactoryV2PipelineRun `
	-ResourceGroupName $ResGrp.ResourceGroupName `
	-DataFactoryName $DataFactoryName `
	-PipelineRunId $RunId
	if ($Run) {
		if ($run.Status -ne 'InProgress') {
			Write-Output ("Pipeline run finished. The status is: " + $Run.Status)
			$Run
			break
			}
		Write-Output "Pipeline is running...status: InProgress"
		}
	Start-Sleep -Seconds 10
}

-- copy activity run details
Write-Output "Activity run details:"
$Result = Get-AzDataFactoryV2ActivityRun
-DataFactoryName $DataFactoryName `
-ResourceGroupName $ResGrp.ResourceGroupName
-PipelineRunId $RunId -RunStartedAfter (Get-Date).AddMinutes(-30)
-RunStartedBefore (Get-Date).AddMinutes(30)
$Result
Write-Output "Activity 'Output' section:"
$Result.Output -join "`r`n"
Write-Output "Activity 'Error' section:"
$Result.Error -join "`r`n"

----------------------------------------------------------------------------------------------------------------
-- 011. Clean up resources
----------------------------------------------------------------------------------------------------------------
Remove-AzResourceGroup -ResourceGroupName $ResourceGroupName

Remove-AzDataFactoryV2 -Name $dataFactoryName -ResourceGroupName $resourceGroupName

----------------------------------------------------------------------------------------------------------------
-- 012. Create Azure Data Factory Data Flow
----------------------------------------------------------------------------------------------------------------
* Data Factory 	: NicholasDataFactory
* Version	: V2

* Template	: Transform data using data flow

Copy data from Azure Blob storage to a database in
Azure SQL Database by using Azure Data Factory

--===========================================================================================================================
-- Lab 8 : Shared Self Hosted Integration Runtime in Azure Data Factory
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=9BvU_NpntSg&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=16

2. Create another Data Factory : 'NicholasADFLab'

3. Goto existing Data Factory where Self-Hosted IR installed ('DataFactory0318')
	ADF portal -> Manage -> Connection ->
	Integration Runtime ->
	Choose IR 			->
	Sharing 			->
	Grant permission to another Data Factory ->
	Select another ADF 	->
	Add 			->
	Copy Resource ID	->

	Goto 'NicholasADFLab' ADF ->
	IR 			->
	New			->
	Azure, Self-Hosted	->
	Linked Self-Hosted	->
	Name : Sharing-Self-IR ->
	Resource ID	: Paste the copied Resource ID ->
	Create

--===========================================================================================================================
-- Lab 9 : Parameterize Linked Services in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=M22Mj0rcBcs&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=17

2. Scenario
	* All values (Server name / Database name / User name / Password) can be parameterized
	* 3 DBs and same user ID/Password in this Lab

3. Create Linked service	->
	Name			-> LS_ASQL_Param
	Account selection method -> Enter manually
	Domain name		-> sqlserver0318.database.windows.net
	Authentication type 	-> SQL Authentication
	User name		-> serveradmin
	Password		-> Dkagh0318
	Parameters		-> dbName
	Database name		-> Add dynamic content
		Add		-> @linkedService().dbName
	
	* Check Code		->
		{
			"name": "LS_ASQL_Param",
			"type": "Microsoft.DataFactory/factories/linkedservices",
			"properties": {
				"parameters": {
					"dbName": {
						"type": "string"
					}
				},
				"annotations": [],
				"type": "AzureSqlDatabase",
				"typeProperties": {
					"connectionString": "integrated security=False;encrypt=True;connection timeout=30;
						data source=sqlserver0318.database.windows.net;initial catalog=@{linkedService().dbName};user id=serveradmin",
					"encryptedCredential": "ew0KICAiVmVyc2lvbiI6ICIyMDE3LTExLTMwIiwNCiAgIlByb3RlY3Rpb25Nb2RlIjogIktleSIsDQogICJTZWNyZXRD
						b250ZW50VHlwZSI6ICJQbGFpbnRleHQiLA0KICAiQ3JlZGVudGlhbElkIjogIkRBVEFGQUNUT1JZMDMxOF9kZmQ0NmFkOC05ZjIzLTRkOTctYmRkNC1kMmZjZmJlYjgxZjYiDQp9"
				}
			}
		}

--===========================================================================================================================
-- Lab 10 : Parameterize Datasets in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=9XSJih4k-l8&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=18

2. Create dataset	->
	Name		-> DS_ASQL_Source_Param
	Linked service	-> LS_ASQL_Param
	OK

3. Dataset properties
	New parameters	->
		TableName
		dbNameFromDataSet
	Connection	->
	dbName		-> @dataset().dbNameFromDataSet
	Table		-> Edit
	Schema		-> dbo
	Table name 	-> @dataset().TableName
	
--===========================================================================================================================
-- Lab 11 : Parameterize Pipelines in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=2u6Mo47A9JA&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=19

2. Create pipeline		->
	Name			-> PL_COM_Parameterize
	Create parameters	->
		tblName_PL
		SRCdbName_PL
		TGTdbName_PL

	Source			-> DS_ASQL_Source_Param
		TableName	-> @pipeline().parameters.tblName_PL
		dbNameFromDataSet -> @pipeline().parameters.SRCdbName_PL

	Sink			-> DS_ASQL_Source_Param
		TableName	-> @pipeline().parameters.tblName_PL
		dbNameFromDataSet -> @pipeline().parameters.TGTdbName_PL

3. Trigger now
	tblName_PL	-> customer
	SRCdbName_PL	-> SQL0318
	TGTdbName_PL	-> SQL0319

--===========================================================================================================================
-- Lab 12 : System Variables in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=-VtZtajW2Hc&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=20

2. Pipeline scope
	@pipeline().DataFactory		Name of the data factory the pipeline run is running within
	@pipeline().Pipeline 		Name of the pipeline
	@pipeline().RunId 		ID of the specific pipeline run
	@pipeline().TriggerType 	Type of the trigger that invoked the pipeline (Manual, Scheduler)
	@pipeline().TriggerId 		ID of the trigger that invokes the pipeline
	@pipeline().TriggerName 	Name of the trigger that invokes the pipeline
	@pipeline().TriggerTime 	Time when the trigger that invoked the pipeline.
					The trigger time is the actual fired time, not the scheduled time.
					For example, 13:20:08.0149599Z is returned instead of 13:20:00.00Z

3. Schedule Trigger scope
	@trigger().scheduledTime	Time when the trigger was scheduled to invoke the pipeline run.
					For example, for a trigger that fires every 5 min, this variable would
					return 2017-06-01T22:20:00Z, 2017-06-01T22:25:00Z, 2017-06-01T22:30:00Z respectively.
	@trigger().startTime		Time when the trigger actually fired to invoke the pipeline run.
					For example, for a trigger that fires every 5 min, this variable might return something like
					this 2017-06-01T22:20:00.4061448Z, 2017-06-01T22:25:00.7958577Z, 2017-06-01T22:30:00.9935483Z respectively.
					(Note: The timestamp is by default in ISO 8601 format)

4. Tumbling Window Trigger scope
	@trigger().outputs.windowStartTime	Start of the window when the trigger was scheduled to invoke the pipeline run.
						If the tumbling window trigger has a frequency of "hourly" this would be the time at the beginning of the hour.
	@trigger().outputs.windowEndTime	End of the window when the trigger was scheduled to invoke the pipeline run.
						If the tumbling window trigger has a frequency of "hourly" this would be the time at the end of the hour.

--===========================================================================================================================
-- Lab 13 : Different Author Modes in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=4E98C4Pdip8&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=72

2. Advantages of Git Integration
	* Version CONTROLFILE
	* Partial saves
	* Collaboration and control
	* Better CI/CD
	* Better performance

3. ADF portal -> Left top -> Setup code repository ->
	Repository type : Azure DevOps Git or GitHub

--===========================================================================================================================
-- Lab 14 : Setup GitHub Code Repository for ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=5SEL-XIlzso&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=73

2. Login GitHub
	New repository	-> 'NicholasADFLab' -> Public

3. Create test file (testfile.txt) on Master

4. ADF portal		->
	NicholasADFLab	->
	Data factory	-> Setup code repository
	Repository type	-> GitHub
	GitHub Account	-> zoomok
	Git repository name	-> NicholasADFLab
	Apply

5. Goto GitHub (https://github.com/zoomok/NicholasADFLab)
	Folders and files are generated at Collaboration branch (master)

6. Every time save -> Source(JSON) is updated in GitHub

7. Publish -> Saved in Data factory service as well

8. New branch (Feature branch) -> 'OBIEE'

9. Add dataset and linkes service to pipeline. Save at 'OBIEE' feature branch

10. When try to publish, it alerts 'Publish is only alllowed from collaboration('master'))' branch

11. From ADF, Create Pull request -> Merge to Collaboration branch (Master)

12. From GitHub, Confirm Merge request

13. From ADF, repoint to master from OBIEE

14. Publish

--===========================================================================================================================
-- Lab 15 : Setup Azure DevOps Git Code Repository for ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=vPUnURzXJSQ&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=74

* Oragnization -> Projects -> Repos -> Branches
* repos -> master (collaboration branch), EmployeeA -> changes -> PULL request
* collaboration branch -> Final code
* Feature branches :
	EmployeeA
	EmployeeB
* Single Repository can be associated with only one Azure Data Factory
* Similar pattern to GitHub

--===========================================================================================================================
-- Lab 16 : Use Azure Key Vault Secrets in ADF
--===========================================================================================================================
1. Link ; https://www.youtube.com/watch?v=9BawMq0CVbs&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=75

2. What is Azure key valut :
	- A cloud service that provides a secure store for secrets
	- You can securely store keys, passwords, certificates and other secrets
	- You can store credentials or secret values in an Azure Key vault and use them in ADF linked service

3. Create Key Vault :
	All resources	-> Add
	Resource group	-> ASA_RG
	Key Vault	-> 'KV-ADF-Nicholas'
	Region		-> Australia east
	Pricing tier	-> Standard
	Create

4. Apply to blob storage
	open blob storage	-> blobstorage0318
	Access key		->
	Copy connection string	-> Key 1
		DefaultEndpointsProtocol=https;AccountName=blobstorage0318;AccountKey=TMRw+KzSH9+7CE3DQlJ1nJ1s219CjNVwkAYTtWkCzj
		AyOFqyPoeeuG8z73l3as7n2RpviAUUXE8SaBNGcIH3Ug==;EndpointSuffix=core.windows.net

	* Goto 'KV-Nicholas-ADF'
	- Secrets :
		Generate/Import		->
		Upload options		-> Manual
		Name			-> sec-blobstorage0318-connectionstring
		Value			->
			DefaultEndpointsProtocol=https;AccountName=blobstorage0318;AccountKey=TMRw+KzSH9+
			7CE3DQlJ1nJ1s219CjNVwkAYTtWkCzjAyOFqyPoeeuG8z73l3as7n2RpviAUUXE8SaBNGcIH3Ug==;EndpointSuffix=core.windows.net
		Create

	- Access policy :
		Add access policy	-> 
		Secret permissions	-> Get / List
		Select principal	-> NicholasADFLab
		Add

	Save

5. Create linked service using key vault
	- Create AKV linked service :
		Name		-> LS_KV_BlobStorage0318
		Base URL 	-> https://KV-Nicholas-ADF.vault.azure.net/
		Test connection

	- Create Blog storage linked service
		Name			-> LS_Blobstorage0318
		Select 			-> 'Azure Key Vault'
		AKV linked service	-> LS_KV_BlobStorage0318
		Secret name		-> sec-blobstorage0318-connectionstring
		Test connection

--===========================================================================================================================
-- Lab 17 : Continuous integration and delivery (CI/CD) in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=jJcikWOUqOk&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=76

	* CI : Continuous Integration
	* CD : Continuous Delivery

- Two methods :
1. Automated deployment using Data Factory`s integration with Azure Pipelines (O)
2. Manually upload a Resource Manager template using Data factory UX integration with Azure Resouce Manager (X)

-- Very long tutorial, please refer to link

--===========================================================================================================================
-- Lab 18 : Annotations in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=VUpKBtYrIW0&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=78

2. What is Annotations?
	- Annotations are like Tags
	- We can tag our pipelines with some name and then we can use that name to filter while monitoring
	- When run bunch of pipelines at the same time, you can filter in Monitor by pipelines name or annotations.
	- Annotations is a group name for business classification
	- We can apply annotations on below ADF components : Pipelines / Linked services / Triggers

--===========================================================================================================================
-- Lab 19 : Global Parameters in ADF
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=OILlVDPzZXM&list=PLMWaZteqtEaLTJffbbBzVOv9C0otal1FO&index=80

2. What are Global Parameters?
	- Global parameters are constants across a data factory that can be consumed by a pipeline in any expression
	- Ther`re useful when you have multiple pipelines with identical parameter names and values

--===========================================================================================================================
-- Lab 20 : How to Load Multiple Files in Parallel in Azure Data Factory - Part 1
--===========================================================================================================================
1. Link : https://www.mssqltips.com/sqlservertip/6281/how-to-load-multiple-files-in-parallel-in-azure-data-factory--part-1/
          https://www.mssqltips.com/sqlservertip/6282/azure-data-factory-multiple-file-load-example--part-2/

2. Scenario :
	- We need to load flat files from various locations into an Azure SQL Database
	- The schema of the flat files can change per type of file and even the delimiter changes sometimes

3. Setup :
	* 3 CSV files
		- TopMovies_Part1.csv (semicolon)
		- TopMovies_Part2.csv (semicolon)
		- TopMovies_Part3.csv (comma)
	
	* upload to data lake
		- Add Container : csv
		- Folder : semicolon/TopMovies_Part1.csv; TopMovies_Part2.csv
		- Folder : comma/TopMovies_Part3.csv
	
	* Create a table
		- Database	: SQL0318
		- Table		: Metadata_ADF
			CREATE TABLE dbo.Metadata_ADF
			(
			ID INT IDENTITY(1,1) NOT NULL,
			SourceType VARCHAR(50) NOT NULL,
			ObjectName VARCHAR(500) NOT NULL,
			ObjectValue VARCHAR(1000) NOT NULL
			);

		- Insert Meta data
		INSERT INTO dbo.[Metadata_ADF]
				(
				SourceType,
				ObjectName,
				ObjectValue
				)
		VALUES  ('BlobContainer','semicolondata','semicolon'),
				('BlobContainer','commadata','comma');

		INSERT INTO dbo.[Metadata_ADF]
				(
				SourceType,
				ObjectName,
				ObjectValue
				)
		VALUES  ('Delimiter','semicolondata',';'),
				('Delimiter','commadata',',');

		INSERT INTO dbo.[Metadata_ADF]
				(
				SourceType,
				ObjectName,
				ObjectValue
				)
		VALUES  ('SQLTable','semicolondata','topmovies_semicolon'),
				('SQLTable','commadata','topmovies_comma');

		- Table		: Target tables
		CREATE TABLE [dbo].[topmovies_semicolon]
		(
		[Index] [BIGINT] NULL,
		[MovieTitle] varchar(500) NULL
		);
		 
		CREATE TABLE [dbo].[topmovies_comma]
		(
		[Index] [BIGINT] NULL,
		[MovieTitle] varchar(500) NULL
		);

4. ADF : Linked Service and Data sets
	* Data factory : datafactory-0318
	
	* Linked service
		- Data lake : LS_ADLS
		- Azure SQL	: LS_ASQL
	
	* Data sets
		- Name			: DS_ADLS_CSV_Movies_Dynamic
		- Linked service 	: LS_ADLS
		- Container		: csv
		- Schema tab 		: Clear
		- Parameters tab	: Add 2 parameters
			- FolderName
			- DelimiterSymbol
		- Connection tab
			- Folder 	: @dataset().FolderName
			- Column delimiter : Edit and @dataset().DelimiterSymbol
		
		- Name			: DS_ASQL_Movies_Dynamic
		- Linked service	: LS_ASQL
		- Parameters tab	: Add 'TableName'
		- Connection tab
			- Table		: dbo + . + @dataset().TableName

	* Pipeline
		- Name			: 01-PL_MV_ADLS_ASQL_Multiple_Files

		- Add Lookup Activity
			- Name		: Lookup_Get_Metadata
			- Settings
				- Source data	: DS_ASQL_Movies_Dynamic
				- Table name	: _notSet
				- Query			:
					SELECT	b.[ObjectName]
							,FolderName = b.[ObjectValue]
							,SQLTable   = s.[ObjectValue]
							,Delimiter  = d.[ObjectValue]
					FROM 	[dbo].[Metadata_ADF] b
						JOIN [dbo].[Metadata_ADF] s ON b.[ObjectName] = s.[ObjectName]
						JOIN [dbo].[Metadata_ADF] d ON b.[ObjectName] = d.[ObjectName]
					WHERE   b.[SourceType] = 'BlobContainer'
					AND 	s.[SourceType] = 'SQLTable'
					AND 	d.[SourceType] = 'Delimiter';

		- Add ForEach Activity
			- Name		: Loop over Metadata
			- Sequential	: Unchecked
			- Settings	: @activity('Lookup_Get_Metadata').output.value

			- Activity
				- Add Copy Activity
					- Name		: Copy Blob to SQL
					- Source
						- Source dataset	: DS_ADLS_CSV_Movies_Dynamic
						- Folder name		: @{item().FolderName}
						- DelimiterSymbol	: @{item().Delimiter}
						- Wildcard file path : *.csv
					- Sink
						- sink dataset		: DS_ASQL_Movies_Dynamic
						- TableName		: @{item().SQLTable}
						- Pre-copy		: truncate table dbo.@{item().SQLTable}


--#################################################################################################################################################################
--#################################################################################################################################################################
-- 2. Azure Synapse Analytics				###########################################################################################################
--#################################################################################################################################################################
--#################################################################################################################################################################

--===========================================================================================================================
-- Lab 1 : Azure Synapse Analytics
--===========================================================================================================================
1. Link : https://www.udemy.com/course/azure-sql-data-warehouse-synapse-analytics-service/learn/lecture/18528288#overview

2. What is the Azure Synapse?
	- Synapse is the next generation of Azure SQL Data Warehouse
	- Blending big data analytics, data warehousing and data integration into a single unified service
	- Provide end-to-end analytics with limitless scale

3. Architecture
	---------------------------------------------------------------------------------------------------------------------------------------------------------
	|	On-premises data |						Synapse Studio					|				|
	|	Cloud data	 |	==> Integration + Management + Monitoring + Security  					| ==> Azure Machine Learning	|	
	|	Saas data	 |												|   Power BI			|
	|			 |						Analytics Runtimes				|				|
	|			 |					--------------------------		  	  	|				|
	|			 |						  SQL		Spark				|				|
	|			 |					--------------------------			  	|				|
	|			 |					  Azure Data Lake Storage			  	|				|
	---------------------------------------------------------------------------------------------------------------------------------------------------------
	
4. Create Azure Synapse Analytics (formerly known as Azure SQL Data Warehouse)
	- Subscription 		: Free trial
	- Resource Group	: RG_ASA (new)
	- SQL pool name		: Synapse0318
	- Server		: sqlserver0318
	- Performance level	: Gen2 (DW100c : 2.07 AUD / hour)
	- Additional settings : Use existing (Sample)

5. Azure Synapse Analytics
	- Unified experience for all data professionals
	- Studio

--===========================================================================================================================
-- Lab 2 : Azure Synapse Analytics (workspace preview)
--===========================================================================================================================
1. Link : MS_ASA_document_p19.pdf (22 pages)

2. Create a Datalake storage
	- Name			: datalake0318
	- Resource group 	: RG_ASA
	- Type			: Gen2 (data lake)
	- Containers		: users0318

3. Create Azure Synapse Analytics (workspace preview)
	- Subscription 		: Free trial
	- Resource Group	: RG_ASA
	- Workspace name	: workspace0318
	- Region		: East US
	- Datalake Storage	: datalake0318
	- File system name	: users0318
	- SQL On-demand 	: est. cost/TB (6.87 AUD)
	- Create

3. Open Synapse Studio
	- From Azure Portal
	- web.azuresynapse.net
	- https://web.azuresynapse.net/home?workspace=%2Fsubscriptions%2F3688f460-76ee-4b63-b2eb-fb1edd332e
		61%2FresourceGroups%2FRG_ASA%2Fproviders%2FMicrosoft.Synapse%2Fworkspaces%2Fworkspace0318

4. Create a SQL pool
	- Synapse studio
	- Manage -> SQL pools -> New
		Name			: SQLDB1
		Performance level	: DW100C (2.07 AUD)
	
--===========================================================================================================================
-- Lab 3 : Analyze data with SQL dedicated pools
--===========================================================================================================================
1. Link : MS_ASA_document_p19.pdf (25 pages)


2. Load the NYC Taxi Data into SQLDB1
	- Connect to SQLDB1
	- User database SQLDB1
	- SQL : Develope -> TripSQL
SQL>
CREATE TABLE [dbo].[Trip]
(
[DateID] int NOT NULL,
[MedallionID] int NOT NULL,
[HackneyLicenseID] int NOT NULL,
[PickupTimeID] int NOT NULL,
[DropoffTimeID] int NOT NULL,
[PickupGeographyID] int NULL,
[DropoffGeographyID] int NULL,
[PickupLatitude] float NULL,
[PickupLongitude] float NULL,
[PickupLatLong] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DropoffLatitude] float NULL,
[DropoffLongitude] float NULL,
[DropoffLatLong] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PassengerCount] int NULL,
[TripDurationSeconds] int NULL,
[TripDistanceMiles] float NULL,
[PaymentType] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FareAmount] money NULL,
[SurchargeAmount] money NULL,
[TaxAmount] money NULL,
[TipAmount] money NULL,
[TollsAmount] money NULL,
[TotalAmount] money NULL
)
WITH
(
DISTRIBUTION = ROUND_ROBIN,
CLUSTERED COLUMNSTORE INDEX
);

COPY INTO [dbo].[Trip]
FROM 'https://nytaxiblob.blob.core.windows.net/2013/Trip2013/QID6392_20171107_05910_0.txt.gz'
WITH
(
FILE_TYPE = 'CSV',
FIELDTERMINATOR = '|',
FIELDQUOTE = '',
ROWTERMINATOR='0X0A',
COMPRESSION = 'GZIP'
)
OPTION (LABEL = 'COPY : Load [dbo].[Trip] - Taxi dataset')
;

3. Explore the NYC Taxi data in the dedicated SQL pool
	Data			->
	Database		->
	SQLDB1			->
	dbo.trip		->
	New SQL script 	-> Select top 100 rows
	Change the view to Cart
SQL>
SELECT  passengerCount,
        sum(TripDistanceMiles) as SumTripDistance,
        avg(TripDistanceMiles) as AvgTripDistance
FROM    dbo.Trip
GROUP BY passengerCount
ORDER BY passengerCount
;

--===========================================================================================================================
-- Lab 4 : Analyze with Apache Spark
--===========================================================================================================================
1. Link : MS_ASA_document_p19.pdf (27 pages)

2. Data load using Apache Spark
	- Data hub		-> Linked
	- Azure Blob Storage	-> Sample Datasets
	- nyc_tlc_yellow	-> New notebook
	- Add to Notebook
	
-- Cell 1 : create a new Notebook
from azureml.opendatasets import NycTlcYellow
data = NycTlcYellow()
data_df = data.to_spark_dataframe()
display(data_df.limit(10))

-- Cell 2 : create a database
%%spark
spark.sql("CREATE DATABASE IF NOT EXISTS nyctaxi")
val df = spark.read.sqlanalytics("SQLDB1.dbo.Trip")
df.write.mode("overwrite").saveAsTable("nyctaxi.trip")

-- Cell 3 : Extract data
%%pyspark
df = spark.sql("SELECT * FROM nyctaxi.trip")
display(df)

-- Cell 4 : passengercountstats
%%pyspark
df = spark.sql("""
SELECT PassengerCount,
SUM(TripDistanceMiles) as SumTripDistance,
AVG(TripDistanceMiles) as AvgTripDistance
FROM nyctaxi.trip
WHERE TripDistanceMiles > 0 AND PassengerCount > 0
GROUP BY PassengerCount
ORDER BY PassengerCount
""")
display(df)
df.write.saveAsTable("nyctaxi.passengercountstats")

-- Cell 5 : Customize data visualization with Spark and notebooks
%%pyspark
import matplotlib.pyplot
import seaborn
seaborn.set(style = "whitegrid")
df = spark.sql("SELECT * FROM nyctaxi.passengercountstats")
df = df.toPandas()
seaborn.lineplot(x="PassengerCount", y="SumTripDistance" , data = df)
seaborn.lineplot(x="PassengerCount", y="AvgTripDistance" , data = df)
matplotlib.pyplot.show()

-- Cell 6 : Load data from a Spark table into a SQL pool table
%%spark
val df = spark.sql("SELECT * FROM nyctaxi.passengercountstats")
df.write.sqlanalytics("SQLDB1.dbo.PassengerCountStats", Constants.INTERNAL)


--#################################################################################################################################################################
--#################################################################################################################################################################
-- 3. Azure Databricks					###########################################################################################################
--#################################################################################################################################################################
--#################################################################################################################################################################

--===========================================================================================================================
-- Lab 1 : Introduction to Azure Databricks
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=bO7Xad1gOFQ&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=1

2. What is the Azure Databricks?
- Apache Spark-based analytics platform optimized for MS Azure cloud services platform
- Provide one click setup, streamlined workflows and interactive worksapce
- Enables collaboration between data scientists, data engineers and business analysts
- Unstructured data
- Technology able to process that big data and generate some meaningful data
- Transforming
- Apache Spark open source -> Process bigdata

--===========================================================================================================================
-- Lab 2 : Create an Azure Databricks Workspace using Azure Portal
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=S3lI9cpaUy8&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=2

2. Pre-requisites
- Can`t use Azure Free subscription. We need to upgrade it as pay-as-you-go with no spending limit

3. Create workspace
	Workspace name	: DB-Demo
	Subscription	: Free Trial
	Resource group	: Data-Bricks
	Location		: East US
	Pricing Tier	: standard

4. Launch Workspace : https://adb-5566600411974825.5.azuredatabricks.net/?o=5566600411974825

--===========================================================================================================================
-- Lab 3 : Create Databricks Community Edition Account
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=laeuQnNuiqs&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=3

2. What is Databricks Community Edition
	- Community edition is life-time free Databricks service
	- https://community.cloud.databricks.com/login.html

--===========================================================================================================================
-- Lab 4 : Workspace in Azure Databricks
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=OUVUiVbI2UU&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=4

2. What is workspace?
	- An environment for accessing all your Azure Databricks  assets
	- Folders are composed of Notebook / Libraries / Experiments
	- Can manage the workspace using workspace UI, Databricks CLI and Databricks REST API
	- The shortcuts link displays keyboard shortcuts for working with notebooks

--===========================================================================================================================
-- Lab 5 : Workspace assets in Azure Databricks
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=8oobJhnWp6k&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=5

2. Workspace Assets
	- Clusters	: Set of computation resources and configurations
	- Notebooks	: Web-based interface to documents containing a series of runnable cells (commands)
	- Jobs		: Mechanism for running code in Azure Databricks
	- Libraries	: Makes third-party or locally-built code available to notebooks and jobs running on your clusters
	- Data		: You can import data into a distributed file system mounted into an Azure Databricks workspace
			  and work with it in Azure Databricks notebooks and clusters
	- Experiments	: run MLflow machine learning model trainings

--===========================================================================================================================
-- Lab 6 : Working with Workspace Objects in Azure Databricks
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=lX0cLEAzMT4&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=6

2. Special folders
	- Workspace root folder : Root folder containing all objects
	- Shared		: For sharing objects across your organization
	- Users			: A folder for each user

--===========================================================================================================================
-- Lab 7 : Create and Run Spark Job in Databricks
--===========================================================================================================================
1. Link : https://www.youtube.com/watch?v=9p4Evw7EzTw&list=PLMWaZteqtEaKi4WAePWtCSQCfQpvBT2U1&index=7

2. Steps
	- Create Cluster
	- Create Notebook
	- Create table from CSV file	: File upload to /FileStore/tables/FactInternetSales_2012.csv
	- Query Table
	- Visualize Query Results

3. Run and see data

--#################################################################################################################################################################
--#################################################################################################################################################################
-- 4. SQL Server					###########################################################################################################
--#################################################################################################################################################################
--#################################################################################################################################################################

--===========================================================================================================================
-- Lab 1 : Pricing Tiers
--===========================================================================================================================
* DTU : Used in Non-Production, CPU performance
		| Basic
		| Standard
		| Premium : Sacle-out, Zone-redundant

* vCore	 : Production
	| General Purpose	| Provisioned									| Azure
				| Serveless	(Compute resources are auto-scaled, Billed per second)		| Hybrid
	| Hyperscale		| Secondary Replicas, Very large OLTP database					| Benefit
	| Business Critical	| high transaction rate and lowest latency I/O,					| (55% discount)
				  for Business critical system

** DTU : We can just like the DTU to the horsepower in a car because it directly affects the performance of the database.
		 DTU represents a mixture of the following performance metrics as a single performance unit for Azure SQL Database
		 * CPU
		 * Memory
		 * Data I/O and Log I/O

--===========================================================================================================================
-- Lab 2 : Elastic Pools
--===========================================================================================================================
* Overprovisioned resources
* Underprovisioned resources
* Pool resources
	* 100 DTU : Shared across 4 databases
* Create Elastic pool as Server level not database level
* Database -> Overview :
	1. Elastic Pool Name : NickElasticPool
	2. Configure elastic pool : basic
	3. 50 eDTUs + 4.88 GB
	4. Check : NickSQLDB -> nicksqlserver -> SQL elastic pools
* Add database to Elastic Pools :
	* NickElasticPool -> Configure -> Databases -> Add databases -> NickSQLDB -> Save
	* Check : NickElasticPool -> Configure -> Databases -> Currently in this pool

-- Reset
* Remove Elastic Pools :
	* NickElasticPool -> Configure -> Databases -> Remove from the Pool -> NickSQLDB -> Save
	* NickElasticPool -> Remove
* Delete Database : NickSQLDB
* Delete SQL Server : nicksqlserver

--===========================================================================================================================
-- Lab 3 : Failover Group
--===========================================================================================================================
* Database Server (nicksqlserver)
* Failover Group -> Add group -> group name (failovergroupnick) -> Secondary server (nicksqlserver2) ->
  Database within the group (NickSQLDB) -> create -> take 5 mins
* nicksqlserver -> failovergroupnick -> 
	* Read/write listener endpoint 	: Application can use this URL to keep connection regardless of failover and changed DB Server
					  Always point to primary server even after failover to change DB Server
					  Single end point
					  (failovergroupnick.database.windows.net)
	* Read-only listener endpoint 	: Same as but read-only access
					  (failovergroupnick.secondary.database.windows.net)
* nicksqlserver -> failovergroupnick -> failover -> check DB connection
* Geo-Replication applied this change automatically

* Reset : 
	1. Delete FailoverGroup
	2. Delete NickSQLDB (nicksqlserver2/NickSQLDB)
	3. Delete NickSQLDB (nicksqlserver/NickSQLDB)
	4. Delete nicksqlserver2
	5. Delete nicksqlserver

--===========================================================================================================================
-- Lab 4 : Dynamic Data Masking
--===========================================================================================================================
* Sensitive information doesn`t not visible
* NickSQLDB -> Create demo table
	create table dbo.DemoTable
	(
	Name varchar(50),
	Email varchar(100)
	);

	insert into dbo.DemoTable values ('Nick','zoomok@gmail.com');

	select	*
	from	dbo.DemoTable
	;

* NickSQLDB -> Security/Dynamic data masking -> Add mask :
	1. Schema	: dbo
	2. Table 	: DemoTable
	3. Column 	: Email
	4. Masking field format : Email
	5. Add -> Save

* SQL users excluded from masking (administrators are always excluded) :
	Null (or Add dbuser to exclude)

* Create DB user :
	* Databases -> Security -> New -> Login
	-- ======================================================================================
	-- Create SQL Login template for Azure SQL Database and Azure SQL Data Warehouse Database
	-- ======================================================================================
	CREATE LOGIN demouser
		WITH PASSWORD = 'Dkagh0318' 
	GO
	
	* NickSQLDB -> Security -> Users -> New user
	-- ========================================================================================
	-- Create User as DBO template for Azure SQL Database and Azure SQL Data Warehouse Database
	-- ========================================================================================
	-- For login <login_name, sysname, login_name>, create a user in the database
	CREATE USER demouser
		FOR LOGIN demouser
		WITH DEFAULT_SCHEMA = dbo
	GO

	-- Add user to the database owner role
	EXEC sp_addrolemember N'db_datareader', N'demouser'
	GO;

	-- DB : master (for SSMS Connection)
	CREATE USER demouser FROM LOGIN demouser;

* Test : Query Editor -> Login (demouser / Dkagh0318)
select	*
from	dbo.demotable;
-->
Name	Email
------- -----------------
Nick	zXXX@XXXX.com

--===========================================================================================================================
-- Lab 5 : Auditing
--===========================================================================================================================
* Security -> Auditing
* Default is Disabled
* Enable :
	Storage :
		Configure 			->
		Storage Account 	->
		Create new 			-> Name (mysqlauditing)
		storage (general purpose v1) ->
		Performance (standard) -> Replication (Locally-redundant storage : LRS)
		Retention days (30) -> OK -> Save

* All resources -> Storage account (mysqlauditing) -> Storage explorer -> BLOB Containers -> sqldbauditlogs ->
	nicksqlserver -> NickSQLDB -> sqlDbAuditing_Audit -> 2020-07-25 -> 08_50_20_253_0.xel
	
* Test :
	create table dbo.DemoUserAudit
	(
	AuditLog varchar(max)
	);

	select	*
	from	dbo.DemoUserAudit
	;

* Check storage explorer -> Download xel file -> Open with SSMS

* Reset : 
	1. Delete storage account (sqlauditing)
	2. Delete NickSQLDB
	3. Delete nicksqlserver
	4. Delete Resource Account

--===========================================================================================================================
-- Lab 6 : Using Covering Indexes to Improve Query Performance
--===========================================================================================================================
-- set showplan_all on
-- set showplan_all off
-----------------------------------------------------------------------------------------------
-- Clustered Index
-----------------------------------------------------------------------------------------------
ALTER TABLE [Sales].[Customer] ADD  CONSTRAINT [PK_Customer_CustomerID] PRIMARY KEY CLUSTERED 
(
	[CustomerID] ASC
)WITH (
	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
	IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY]
;

-- set showplan_all on
select	c.*
from	sales.Customer c
where	c.CustomerID = 123
;

select c.CustomerID,    c.AccountNumber  from sales.Customer c  where c.CustomerID = 123  ;
  |--Compute Scalar(DEFINE:([c].[AccountNumber]=[AdventureWorks2012].[Sales].[Customer].[AccountNumber] as [c].[AccountNumber]))
       |--Compute Scalar(DEFINE:([c].[AccountNumber]=isnull('AW'+[AdventureWorks2012].[dbo].[ufnLeadingZeros]
       		([AdventureWorks2012].[Sales].[Customer].[CustomerID] as [c].[CustomerID]),'')))
            |--Clustered Index Seek(OBJECT:([AdventureWorks2012].[Sales].[Customer].[PK_Customer_CustomerID]
	    	AS [c]), SEEK:([c].[CustomerID]=CONVERT_IMPLICIT(int,[@1],0)) ORDERED FORWARD)

-----------------------------------------------------------------------------------------------
-- Nonclustered Index
-----------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX [IX_Customer_PersonID_TerritoryID] ON [Sales].[Customer]
(	[PersonID] ASC,
	[TerritoryID] ASC
)
WITH (
	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
	ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	)
ON [PRIMARY]
;

select	c.PersonID,
		c.TerritoryID,
		c.StoreID
from	sales.Customer c
where	c.PersonID = 20613
;

select c.PersonID,    c.TerritoryID,    c.StoreID  from sales.Customer c  where c.PersonID = 20613
  |--Nested Loops(Inner Join, OUTER REFERENCES:([c].[CustomerID]))
       |--Index Seek(OBJECT:([AdventureWorks2012].[Sales].[Customer].[IX_Customer_PersonID_TerritoryID]
       		AS [c]), SEEK:([c].[PersonID]=(20613)) ORDERED FORWARD)
       |--Clustered Index Seek(OBJECT:([AdventureWorks2012].[Sales].[Customer].[PK_Customer_CustomerID]
       		AS [c]), SEEK:([c].[CustomerID]=[AdventureWorks2012].[Sales].[Customer].[CustomerID] as [c].[CustomerID]) LOOKUP ORDERED FORWARD)

select	c.PersonID,
		c.TerritoryID,
		c.StoreID
from	sales.Customer c
where	c.PersonID between 1 and 20613
;

select c.PersonID,    c.TerritoryID,    c.StoreID  from sales.Customer c  where c.PersonID between 1 and 20613
  |--Clustered Index Scan(OBJECT:([AdventureWorks2012].[Sales].[Customer].[PK_Customer_CustomerID] AS [c]),
  	WHERE:([AdventureWorks2012].[Sales].[Customer].[PersonID] as [c].[PersonID]>=(1)
		AND [AdventureWorks2012].[Sales].[Customer].[PersonID] as [c].[PersonID]<=(20613)))

select	c.PersonID,
		c.TerritoryID
from	sales.Customer c
where	c.PersonID between 20000 and 20613
;

select c.PersonID,    c.TerritoryID  from sales.Customer c  where c.PersonID between 20000 and 20613  ;
  |--Index Seek(OBJECT:([AdventureWorks2012].[Sales].[Customer].[IX_Customer_PersonID_TerritoryID] AS [c]),
  	SEEK:([c].[PersonID] >= CONVERT_IMPLICIT(int,[@1],0) AND [c].[PersonID] <= CONVERT_IMPLICIT(int,[@2],0)) ORDERED FORWARD)
 
------------------------------------------------------------------------------------------
-- Including Non-Key columns (Covering index)
------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX [IX_Customer_PersonID_TerritoryID_Store_ID] ON [Sales].[Customer]
(	[PersonID] ASC,
	[TerritoryID] ASC
)
INCLUDE([StoreID]) --> Include multiple columns
WITH (
	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
	ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	)
ON [PRIMARY]
;

select	c.PersonID,
		c.TerritoryID,
		c.StoreID
from	sales.Customer c
where	c.PersonID between 1 and 20613
;

select c.PersonID,    c.TerritoryID,    c.StoreID  from sales.Customer c  where c.PersonID between 1 and 20613
  |--Index Seek(OBJECT:([AdventureWorks2012].[Sales].[Customer].[IX_Customer_PersonID_TerritoryID_Store_ID] AS [c]),
  	SEEK:([c].[PersonID] >= (1) AND [c].[PersonID] <= (20613)) ORDERED FORWARD)
  
--===========================================================================================================================
-- Lab 7 : Azure SQL Database - Table Partitioning
--===========================================================================================================================
-- set showplan_all on
-- set showplan_all off

1. Link : https://www.mssqltips.com/sqlservertip/3494/azure-sql-database--table-partitioning/

2. Scenario : Calculate and store the primes numbers from 1 to 1 million with ten data partitions.
	      Thus, the primes numbers will be hashed in buckets at every one hundred thousand mark

3. Create databaes MATH
USE [master]
GO

-- Delete existing database
IF  EXISTS (SELECT name FROM sys.databases WHERE name = N'MATH')
DROP DATABASE MATH
GO

-- Create new database
CREATE DATABASE MATH
(
MAXSIZE = 20GB,
EDITION = 'STANDARD',
SERVICE_OBJECTIVE = 'S2'
)
GO  

4. Create partition function
create partition function pf_hash_by_value (bigint) as range left
for values (100000, 200000, 300000, 400000, 500000, 600000, 700000, 800000, 900000)
go

select	*
from	sys.partition_functions
;

5. Create partition scheme
create partition scheme ps_hash_by_value
as partition pf_hash_by_value
all to ([Primary]);
;

select	*
from	sys.partition_schemes
;

6. Partition system function
select	My_Value,
		$partition.pf_hash_by_value(My_Value) as hash_indx
from	(
		values
		(1),
		(100001),
		(200001),
		(300001),
		(400001),
		(500001),
		(600001),
		(700001),
		(800001),
		(900001)
		) as TEST (My_Value)
;

7. Create the partitioned table
if exists
	(
	select	*
	from	sys.objects
	where	object_id = object_id(N'[dbo].[Tbl_Primes]') and type in (N'U')
	)
drop table [dbo].[Tbl_Primes]

go

create table [dbo].[Tbl_Primes]
(
My_Value	bigint not null,
My_Division	bigint not null,
My_Time		datetime not null constraint DF_Tbl_Primes default getdate()
constraint PK_Tbl_Primes primary key clustered (My_Value asc)
) on ps_hash_by_value (My_Value)
;

8. create a procedure that takes a number as a parameter and determines if it is prime

create procedure sp_is_prime
	@var_num2 bigint
as
begin
	set nocount on

	declare @var_cnt2 bigint;
	declare @var_max2 bigint;

	if (@var_num2 = 1)
		return 0;

	if (@var_num2 = 2)
		return 1;

	select	@var_cnt2 = 2;
	select	@var_max2 = sqrt(@var_num2) + 1;
	
	while (@var_cnt2 <= @var_max2)
	begin
		if (@var_num2 % @var_cnt2) = 0
			return 0;

		select	@var_cnt2 = @var_cnt2 + 1;
	end

	return 1;
end;

9. create a procedure that takes a starting and ending value as input and calculates
   And stores primes numbers between those two values as output

if exists
	(
	select	*
	from	sys.objects
	where	object_id = object_id(N'[dbo].[sp_store_primes]')
	and		type in (N'P', N'PC')
	)
drop procedure [dbo].[sp_store_primes]

go

create procedure sp_store_primes
	@var_alpha bigint,
	@var_omega bigint
as
begin
	set nocount on

	declare @var_cnt1 bigint;
	declare @var_ret1 int;

	select	@var_ret1 = 0;
	select	@var_cnt1 = @var_alpha;

	while (@var_cnt1 <= @var_omega)
	begin
		exec @var_ret1 = dbo.sp_is_prime @var_cnt1;

		if (@var_ret1 = 1)
		insert into tbl_primes (my_value, my_division)
		values (@var_cnt1, sqrt(@var_cnt1));

		select	@var_cnt1 = @var_cnt1 + 1
	end
end
;

10. Execute procedure

exec sp_store_primes 1, 100000
exec sp_store_primes 100001, 200000
exec sp_store_primes 200001, 300000
exec sp_store_primes 300001, 400000
exec sp_store_primes 400001, 500000
exec sp_store_primes 500001, 600000
exec sp_store_primes 600001, 700000
exec sp_store_primes 700001, 800000
exec sp_store_primes 800001, 900000
exec sp_store_primes 900001, 100000

11. Validate data placement
select	partition_number,
		row_count
from	sys.dm_db_partition_stats
where	object_id = object_id('Tbl_Primes')
;
partition_number	row_count
------------------- ----------
1						9592
2						8392
3						8013
4						7863
5						7678
6						7560
7						7445
8						7408
9						7323
10						0

select	$partition.pf_hash_by_value(My_Value) as partition_Number,
		count(*) as Row_Count
from	math.dbo.tbl_primes
group by $partition.pf_hash_by_value(My_Value)
;

partition_Number	Row_Count
------------------ -----------
1						9592
2						8392
3						8013
4						7863
5						7678
6						7560
7						7445
8						7408
9						7323

-- Execution plan
set showplan_all on

select	*
from	tbl_primes
where	my_value = 61027
;

StmtText
select *  from tbl_primes  where my_value = 61027
  |--Clustered Index Seek(OBJECT:([MATH].[dbo].[Tbl_Primes].[PK_Tbl_Primes]),
  	SEEK:([PtnId1000]=RangePartitionNew(CONVERT_IMPLICIT(bigint,[@1],0),(0),
	(100000),(200000),(300000),(400000),(500000),(600000),(700000),(800000),(900000)) AND
	[MATH].[dbo].[Tbl_Primes].[My_Value]=CONVERT_IMPLICIT(bigint,[@1],0)) ORDERED FORWARD)

set showplan_all off

--===========================================================================================================================
-- Lab 8 : Creating backups and copies of your SQL Azure databases
--===========================================================================================================================
1. Link : https://www.mssqltips.com/sqlservertip/2235/creating-backups-and-copies-of-your-sql-azure-databases/

2. Methods
	- The database copy process is asynchronous, which means the database copy command returns immediately and
	  you don`t need an active connection while copying since the actual copy is done by SQL Azure in the background.

	- You can monitor the progress of the database copy using the provided DMVs/catalog views
	- Please note as long as the database copy operation is in progress the original/source database
	  Needs to be online as the copy operation is dependent on it

3. Copy database

create database SQL0318Copy
as copy of SQL0318
go

4. Monitorig
select	*
from	sys.dm_database_copies
;

select	state_desc,
		*
from	sys.databases
