CREATE Procedure [dbo].[usp_DownloadAccountTypes](
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	
print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
select @TSQL = 
'
print ''--Truncating table AccountType...''
TRUNCATE TABLE FISDataMart.dbo.AccountType;

print ''--Downloading all AccountType records...''
INSERT INTO FISDataMart.dbo.AccountType(AccountType, AccountTypeName, LastUpdateDate)
SELECT 
	ACCOUNT_TYPE_CODE AccountType,
	ACCOUNT_TYPE_NAME AccountTypeName,
    DS_LAST_UPDATE_DATE as LastUpdateDate
 FROM OPENQUERY(FIS_DS, 
	''SELECT 
		ACCT_TYPE_CODE ACCOUNT_TYPE_CODE,
		ACCT_TYPE_NAME ACCOUNT_TYPE_NAME,
		DS_LAST_UPDATE_DATE
	FROM FINANCE.ACCOUNT_TYPE
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
