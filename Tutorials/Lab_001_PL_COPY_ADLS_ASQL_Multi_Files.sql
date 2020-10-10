--===========================================================================================================================
-- Lab 1 : How to Load Multiple Files in Parallel in Azure Data Factory - Part 1
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
		- Name				: DS_ADLS_CSV_Movies_Dynamic
		- Linked service 	: LS_ADLS
		- Container			: csv
		- Schema tab 		: Clear
		- Parameters tab	: Add 2 parameters
			- FolderName
			- DelimiterSymbol
		- Connection tab
			- Folder 		: @dataset().FolderName
			- Column delimiter : Edit and @dataset().DelimiterSymbol
		
		- Name				: DS_ASQL_Movies_Dynamic
		- Linked service	: LS_ASQL
		- Parameters tab	: Add 'TableName'
		- Connection tab
			- Table			: dbo + . + @dataset().TableName

	* Pipeline
		- Name				: 001_PL_COPY_ADLS_ASQL_Multi_Files

		- Add Lookup Activity
			- Name			: Lookup_Get_Metadata
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
			- Name			: Loop over Metadata
			- Sequential	: Unchecked
			- Settings		: @activity('Lookup_Get_Metadata').output.value

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
						- TableName			: @{item().SQLTable}
						- Pre-copy			: truncate table dbo.@{item().SQLTable}
						
--(End)----------------------------------------------------------------------------------------------------------------------
