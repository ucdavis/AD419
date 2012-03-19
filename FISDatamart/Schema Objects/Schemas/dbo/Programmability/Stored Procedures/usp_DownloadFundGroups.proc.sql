CREATE Procedure [dbo].[usp_DownloadFundGroups](
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
select @TSQL = 
'print ''--Truncating table FundGroups...''
TRUNCATE TABLE [FISDataMart].[dbo].[FundGroups];

print ''--Downloading all FundGroups records...''
INSERT INTO [FISDataMart].[dbo].[FundGroups](
	   [FundGroup]
      ,[FundGroupName]
      ,[LastUpdateDate])
SELECT 
	FUND_GROUP_CODE as FundGroup,
	FUND_GROUP_NAME as FundGroupName,
    DS_LAST_UPDATE_DATE as LastUpdateDate
FROM OPENQUERY(FIS_DS, 
	''SELECT 
		FUND_GROUP_CODE,
		FUND_GROUP_NAME,
		DS_LAST_UPDATE_DATE
	FROM FINANCE.FUND_GROUP
	ORDER BY FUND_GROUP_CODE
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
