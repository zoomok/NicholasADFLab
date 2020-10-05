-- SQL0318
create table dbo.STG_Sales_Rep
(
	SalesRep_Number 	int,
	SalesRep_Name 		varchar(maX),
	SalesRep_Department varchar(max)
)
;

insert into STG_Sales_Rep values
(1,'Michael','Finance')
;

insert into STG_Sales_Rep values
(2,'John','HR')
;

-- SQL0319
create table dbo.Dim_SalesRep
(
	SalesRep_Key 	int identity(1,1) ,
	SalesRep_Number int,
	SalesRep_Name 	varchar(max),
	SalesRep_Department varchar(max)
)
;

-- Test
1. Run ADF (initial load)
2. Update/Insert STG

update	stg_sqles_rep
set		sallesRep_Department = 'IT'
where	salesRep_number = 2;

insert into STG_Sales_Rep values
(5,'Nick','Sales');

3. Run ADF (SCD Type1)
