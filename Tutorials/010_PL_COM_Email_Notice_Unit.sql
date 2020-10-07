--===========================================================================================================================
-- Lab 10 : Azure Data Factory Pipeline Email Unit
--===========================================================================================================================
1. Create a unit pipeline
	- Name	: "010_PL_COM_Email_Notice_Unit"
	- Pipeline parameters
		- EmailTo
		- Subject
		- ErrorMessage

	- Add Web activities
		- Name 		: Send Notification
		- URL 		:
			https://prod-30.eastus.logic.azure.com:443/workflows/9b66a7ff65d4454d881b66c24ed7c3dc/triggers/manual
			/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=pSpKw9-Oq3YjpIneFlVM3loakFNxtSsKPZDQxnn5YEI
		- Method	: Post
		- Body 		:
			{
			   "DataFactoryName": "@{pipeline().DataFactory}",
			   "PipelineName": "@{pipeline().Pipeline}",
			   "Subject": "@{pipeline().parameters.Subject}",
			   "ErrorMessage": "@{pipeline().parameters.ErrorMessage}",
			   "EmailTo": "@{pipeline().parameters.EmailTo}"
			}
