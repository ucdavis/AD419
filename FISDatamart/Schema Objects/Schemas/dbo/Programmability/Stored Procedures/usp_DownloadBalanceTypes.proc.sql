create Procedure [dbo].[usp_DownloadBalanceTypes]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
select @TSQL = 
	'print ''--Truncating table BalanceTypes...''
TRUNCATE TABLE FISDataMart.dbo.BalanceTypes;
	
	print ''--Downloading all BalanceTypes records...''
INSERT INTO FISDataMart.dbo.BalanceTypes (
	   [BalanceTypeCode]
      ,[BalanceTypeName]
      ,[BalanceCategoryCode]
      ,[BalanceCategoryName]
      ,[BalanceReportingTypeCode]
      ,[LastUpdateDate])
SELECT 
	BALANCE_TYPE_CODE as BalanceTypeCode,
	BALANCE_TYPE_NAME as BalanceTypeName,
	BALANCE_CATEGORY_CODE as BalanceCategoryCode,
	BALANCE_CATEGORY_NAME as BalanceCategoryName,
	BALANCE_REPORTING_TYPE as BalanceReportingTypeCode,
    DS_LAST_UPDATE_DATE as LastUpdateDate
 FROM OPENQUERY(FIS_DS, 
	''SELECT BALANCE_TYPE_CODE,
	         BALANCE_TYPE_NAME,
	         CASE WHEN BALANCE_CATEGORY_NAME LIKE ''''%Approp%'''' THEN ''''AP''''
	         WHEN BALANCE_CATEGORY_NAME LIKE ''''%Encumb%'''' THEN ''''EN''''
	         WHEN BALANCE_CATEGORY_NAME LIKE ''''%Expend%'''' THEN ''''EX''''
	         ELSE ''''--''''
	         END AS BALANCE_CATEGORY_CODE,
			 BALANCE_CATEGORY_NAME,
			 BALANCE_REPORTING_TYPE,
			 DS_LAST_UPDATE_DATE
	FROM FINANCE.BALANCE_TYPE_REPORTING
	''
	)
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
