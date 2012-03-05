CREATE Procedure [dbo].[usp_DownloadDocumentTypes](
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
select @TSQL = 
'print ''--Truncating table DocumentTypes...''
TRUNCATE TABLE  [FISDataMart].[dbo].[DocumentTypes];

print ''--Downloading all DocumentTypes records...''
INSERT INTO [FISDataMart].[dbo].[DocumentTypes](
	   [DocumentType]
      ,[DocumentTypeName]
      ,[DocumentGroupCode]
      ,[DocumentGroupName]
      ,[DocumentSubsystemCode]
      ,[DocumentActiveIndicator]
      ,[ChartManagerRoutingIndicator]
      ,[AccountManagerRoutingIndicator]
      ,[ReviewHierarchyRoutingIndicator]
      ,[SpecialConditionsRoutingIndicator]
      ,[LastUpdateDate])
SELECT 
	DOC_TYPE_NUM as DocumentTypes,
	DOC_TYPE_NAME as DocumentType,
	DOC_GROUP_CODE as DocumentGroupCode,
	DOC_GROUP_NAME as DocumentGroupName,
	DOC_SUBSYSTEM_CODE as DocumentSubsystemCode,
	DOC_ACTIVE_IND as DocumentActiveIndicator,
	CHART_MGR_ROUTING_IND as ChartManagerRoutingIndicator,
	ACCT_MGR_ROUTING_IND as AccountManagerRoutingIndicator,
	REVIEW_HIERARCHY_ROUTING_IND as ReviewHierarchyRoutingIndicator,
	SPECIAL_CONDITIONS_ROUTING_IND as SpecialConditionsRoutingIndicator,
    DS_LAST_UPDATE_DATE as LastUpdateDate
FROM OPENQUERY(FIS_DS, 
	''SELECT 
		DOC_TYPE_NUM,
		DOC_TYPE_NAME,
		DOC_GROUP_CODE,
		DOC_GROUP_NAME,
		DOC_SUBSYSTEM_CODE,
		DOC_ACTIVE_IND,
		CHART_MGR_ROUTING_IND,
		ACCT_MGR_ROUTING_IND,
		REVIEW_HIERARCHY_ROUTING_IND,
		SPECIAL_CONDITIONS_ROUTING_IND,
		DS_LAST_UPDATE_DATE
	FROM FINANCE.DOCUMENT_TYPE
	ORDER BY DOC_TYPE_NUM
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
