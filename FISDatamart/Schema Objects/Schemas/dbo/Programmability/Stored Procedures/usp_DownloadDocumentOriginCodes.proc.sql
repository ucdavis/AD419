CREATE Procedure [dbo].[usp_DownloadDocumentOriginCodes](
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
select @TSQL = 
'print ''--Truncating table DocumentOriginCodes''
TRUNCATE TABLE FISDataMart.dbo.DocumentOriginCodes;

print ''--Downloading all DocumentOriginCodes records...''
INSERT INTO FISDataMart.dbo.DocumentOriginCodes(
	   [DocumentOriginCode]
      ,[OriginCodeDescription]
      ,[DocumentOriginDatabaseName]
      ,[DocumentOriginServerName]
      ,[DefaultChart]
      ,[DefaultAccount]
      ,[DefaultObject]
      ,[GLEContactEmail]
      ,[ReferenceControlManagerDaFisId]
      ,[LastUpdateDate])
SELECT 
	DOC_ORIGIN_CODE as DocumentOriginCode,
	DOC_ORIGIN_CODE_DESC as OriginCodeDescription,
	DOC_ORIGIN_DATABASE_NAME as DocumentOriginDatabaseName,
	DOC_ORIGIN_SERVER_NAME as DocumentOriginServerName,
	DEFAULT_CHART_NUM as DefaultChart,
	DEFAULT_ACCT_NUM as DefaultAccount,
	DEFAULT_OBJECT_NUM as DefaultObject,
	GLE_CONTACT_EMAIL_ID as GLEContactEmail,
	REFERENCE_CONTROL_MGR_DAFIS_ID as ReferenceControlManagerDaFisId,
    GETDATE() as LastUpdateDate
 FROM OPENQUERY(FIS_DS, 
	''SELECT 
		DOC_ORIGIN_CODE,
		DOC_ORIGIN_CODE_DESC,
		DOC_ORIGIN_DATABASE_NAME,
		DOC_ORIGIN_SERVER_NAME,
		DEFAULT_CHART_NUM,
		DEFAULT_ACCT_NUM,
		DEFAULT_OBJECT_NUM,
		GLE_CONTACT_EMAIL_ID,
		REFERENCE_CONTROL_MGR_DAFIS_ID
	FROM FINANCE.origin_code
	ORDER BY DOC_ORIGIN_CODE
	'')
'
-------------------------------------------------------------------------
	if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
