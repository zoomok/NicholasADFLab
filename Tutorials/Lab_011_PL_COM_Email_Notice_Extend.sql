--===========================================================================================================================
-- Lab 11 : Azure Data Factory Pipeline Email Notification Extend
--===========================================================================================================================
1. Create a Extend pipeline
		- Name	: 011_PL_COM_Email_Notice_Extend
		- Copy Stored Procedure activity from "006_PL_DATA_StoredProcedure"
		- Add 2 Execute pipeline (010_PL_COM_Email_Notice_Unit) for success and failure
			- Success	:
				EmailTo	: xxx@gmail
				Subject	: @pipeline().Pipeline
				ErrorMessage : Successfully Finished
				
			- Failure	:
				EmailTo	: xxx@gmail
				Subject	: @pipeline().Pipeline
				ErrorMessage : @{activity('Stored procedure for logging').Error.Message}

2. Run pipeline and check email

--(End)----------------------------------------------------------------------------------------------------------------------
