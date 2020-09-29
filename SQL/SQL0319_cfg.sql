use SQL0319
Go

create table cfg
(
Table_Name 	varchar(max),
Source 		varchar(max),
Max_LastUpdatedDate datetime,
Enabled 	int,
Incremental_Full_Load int
)
;