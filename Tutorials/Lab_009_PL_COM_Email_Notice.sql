--===========================================================================================================================
-- Lab 9 : Azure Data Factory Pipeline Email Notification
--===========================================================================================================================
1. Azure portal
	- Add resource 	: Logic App
	- Select 		: When a HTTP request is received
	- JSON format	:
		{
			"properties": {
				"DataFactoryName": {
					"type": "string"
				},
				"EmailTo": {
					"type": "string"
				},
				"ErrorMessage": {
					"type": "string"
				},
				"PipelineName": {
					"type": "string"
				},
				"Subject": {
					"type": "string"
				}
			},
			"type": "object"
		}
	- New step
		- Gmail / Login
		- Send an email
			- "EmailTo"
			- "Subject"
			- The ErrorMessage 		: "ErrorMessage"
			- The data factory name : "DataFactoryName"
			- The pipeline name 	: "PipelineName"
	
	- Test
		- https://apitester.com/
			- Request 	: Test
			- Post		: See trigger history in adf-notification
				https://prod-30.eastus.logic.azure.com:443/workflows/9b66a7ff65d4454d881b66c24ed7c3dc/triggers/manual/paths/
				invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=pSpKw9-Oq3YjpIneFlVM3lo .....
			- Post data	:
				{
						"DataFactoryName": "test",
						"EmailTo": "xxx@gmail.com",
						"ErrorMessage": "This is a test!",
						"PipelineName": "Test",
						"Subject": "Hello world"
				}
			- Request header :
				- Content-Type
				- application/json
			- Test and check Response Headers
			- Check gmail

2. Create a pipeline
	- Clone "006_PL_DATA_StoredProcedure" and rename to 009_PL_COM_Email_Notification
	- Add 2 Web activities
		- Success :
			- Method	: Post
			- Body 		:
			{
			   "DataFactoryName": "@{pipeline().DataFactory}",
			   "PipelineName": "@{pipeline().Pipeline}",
			   "Subject": "Pipeline finished!",
			   "ErrorMessage": "Everything is okey-dokey!",
			   "EmailTo": "xxx@gmail.com"
			}
		- Failure :
			- Method 	: Post
			- Body		:
				{
				   "DataFactoryName": "@{pipeline().DataFactory}",
				   "PipelineName": "@{pipeline().Pipeline}",
				   "Subject": "An error has occurred!",
				   "ErrorMessage": "The ADF pipeline has crashed! Please check the logs.",
				   "EmailTo": "xxx@gmail.com"
				}
	
3. Run pipeline and check email

--(End)----------------------------------------------------------------------------------------------------------------------
