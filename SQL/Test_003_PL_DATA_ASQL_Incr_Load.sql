--------------------------------------------------------------------------------------
-- (Full load)
--------------------------------------------------------------------------------------
-- Current date : (2020-09-13 11:10:11.000)
-- Source (SQL0318)
truncate table customer;
truncate table lead;
truncate table users;

insert into Lead values('John', 'EmailCampaign', 'Hydrolics', getdate()-10); 	--> (2020-09-03)
insert into Lead values('Mike', 'SMSCampaign', 'Crane', getdate()-10);			--> (2020-09-03)

insert into Customer values('John Deere', '345 W MAdison St', 'Chicago', getdate()-11);	--> (2020-09-02)
insert into Customer values('Citibank', '985 W Jackson St', 'New York', getdate()-11);	--> (2020-09-02)

insert into Users values('Nicholas', '46 Crown Point Ridge', getdate()-12);		--> (2020-09-01)
insert into Users values('Sunny', '22 Capricorn Ave', getdate()-12);			--> (2020-09-01)

-- STG (SQL0319)
truncate table cfg;
truncate table customer;
truncate table lead;
truncate table users;

insert into cfg values('Lead', 'CRM', getdate()-20, 1, 0);			--> (2020-08-24)
insert into cfg values('Customer', 'CRM', getdate()-20, 1, 0);		--> (2020-08-24)
insert into cfg values('Users', 'CRM', getdate()-20, 1, 0);			--> (2020-08-24)

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
insert into Lead values('Lead1','EBS','Hydrolics', getdate()-9);	--> (2020-09-04)
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
