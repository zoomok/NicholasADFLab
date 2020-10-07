--======================================================================================================================================
-- Lab 6 : Azure Data Factory Stored Procedure Activity Transformation Activities
--======================================================================================================================================
1. Scenario   :
    - Stored Procedure Activity could be used to run regular batch processes, to log pipeline execution progress or exceptions.
    - We will create a simple stored procedure in the SQL0318 database to store pipeline name, pipeline run ID and sample text.

2. Pipeline name : 006_PL_DATA_StoredProcedure

3. Create stored procedure :
-- SQL0319
CREATE TABLE [dbo].[ExceptionLogs](
 [PipelineName] [varchar](100) NULL,

 [RunId] [varchar](100) NULL,
 [TableName] [varchar](100) NULL
)
GO

CREATE PROCEDURE Usp_ExceptionLog
(@PipelineName varchar(100), @runid varchar(100),@TableName varchar(100)) 
AS
BEGIN
    INSERT INTO ExceptionLogs VALUES(@PipelineName,@runid,@TableName) 
END
GO

4. Develop Pipeline and debug

5. Check table
select	*
from	exceptionlogs
;
