------------------------------------------------------------------------
/*
USP Name: usp_Extract_Raw_FIS_JV_Expenses
BY:	Ken Taylor
USAGE:
SELECT * FROM usp_Extract_Raw_FIS_JV_Expenses()

DESCRIPTION: 

CURRENT STATUS:

NOTES:

*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_Extract_Raw_FIS_JV_Expenses](
-- Parameters:
@FiscalYear int = null,
@IsDebug bit = 0
)

AS
declare @TSQL varchar(MAX) = null
declare @ARCCodes varchar(max) = '';
-------------------------------------------------------------------------
BEGIN

-- Build the list of Annual Report Codes from the ARCCodes view of the 
-- ARC_Codes table
declare @temp varchar(20) = '';

declare MyCursor Cursor for select ARCCode from [FISDataMart].[dbo].[ARCCodes] for READ ONLY

open MyCursor

fetch next from MyCursor into @temp

while @@FETCH_STATUS = 0
begin
	select @ARCCodes +=  '''''' + @temp + '''''' 
	FETCH NEXT FROM MyCursor
    INTO @temp
    
    if @@FETCH_STATUS = 0
    Begin
		select @ARCCodes += ', ' 
    End
end

close MyCursor
deallocate MyCursor
-------------------------------------------------------------------------
select @TSQL = '
SELECT
	Org,
	Account,
	SubAccount,
	ObjConsol,
	Expenses
FROM 
	OPENQUERY 
		(FIS_DS,
		''
SELECT 
	Trans.ORG_ID Org,
	Trans.ACCT_NUM Account,
	Trans.SUB_ACCT_NUM SubAccount,
	Trans.OBJ_CONSOLIDATN_NUM ObjConsol,
	Sum(Trans.TRANS_LINE_AMT) Expenses
FROM 
	FINANCE.ORGANIZATION_HIERARCHY Orgs,
	FINANCE.ORGANIZATION_ACCOUNT  Accounts,
	FINANCE.GL_APPLIED_TRANSACTIONS  Trans
WHERE 
	(
		Accounts.ACCT_NUM = Trans.ACCT_NUM
		AND Accounts.CHART_NUM = ''''3''''
		AND Accounts.FISCAL_YEAR = ' + Convert(char(4), @FiscalYear) + ' 
		AND Accounts.FISCAL_PERIOD = ''''--'''' 
		AND Orgs.ORG_ID = Accounts.ORG_ID
		AND Orgs.CHART_NUM = ''''3''''
		AND Orgs.FISCAL_YEAR = ' + Convert(char(4), @FiscalYear) + ' 
		AND Orgs.FISCAL_PERIOD = ''''--'''' 
	)
	AND Trans.CHART_NUM = ''''3''''
	AND Trans.FISCAL_YEAR = ' + Convert(char(4), @FiscalYear) + ' 
	AND Trans.BALANCE_TYPE_CODE = ''''AC''''
	AND Trans.OBJ_CONSOLIDATN_NUM Not In (''''INC0'''', ''''BLSH'''', ''''SB74'''')
	-- AND Accounts.ANNUAL_REPORT_CODE IN (''''430200'''',''''440200'''',''''440201'''',''''440205'''',''''440206'''',''''440210'''',''''440211'''',''''440218'''',''''440219'''',''''440221'''',''''440222'''',''''440223'''',''''440224'''',''''440225'''',''''440227'''',''''440229'''',''''440230'''',''''440231'''',''''440232'''',''''440233'''',''''440240'''',''''440246'''',''''440247'''',''''440248'''',''''440251'''',''''440253'''',''''440254'''',''''440261'''',''''440287'''',''''440290'''',''''440319'''',''''441016'''',''''441020'''',''''441035'''',''''441038'''',''''441092'''',''''441096'''')
	-- AND Accounts.ANNUAL_REPORT_CODE IN (''''430200'''',''''440200'''',''''440201'''',''''440205'''',''''440210'''',''''440211'''',''''440219'''',''''440221'''',''''440222'''',''''440223'''',''''440224'''',''''440225'''',''''440227'''',''''440229'''',''''440231'''',''''440232'''',''''440233'''',''''440240'''',''''440246'''',''''440247'''',''''440248'''',''''440251'''',''''440287'''',''''440290'''',''''440319'''',''''441016'''',''''441020'''',''''441035'''',''''441038'''',''''441092'''',''''441096'''')
	AND Accounts.ANNUAL_REPORT_CODE IN (' + @ARCCodes + ')
	AND Orgs.ORG_ID_LEVEL_1 IN (''''AAES'''', ''''BIOS'''')
	AND Trans.DOC_TYPE_NUM like ''''JV''''
GROUP BY 
	Trans.FISCAL_YEAR ,
	Trans.ORG_ID ,
	Trans.ACCT_NUM,
	Trans.SUB_ACCT_NUM ,
	Trans.OBJ_CONSOLIDATN_NUM
		'')'
	
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end

END
