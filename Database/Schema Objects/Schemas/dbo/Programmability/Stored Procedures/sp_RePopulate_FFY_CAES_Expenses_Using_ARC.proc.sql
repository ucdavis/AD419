/*
---------------------------------------------------------------------
PROGRAM: sp_RePopulate_FFY_CAES_Expenses_Using_ARC.SQL
By Ken Taylor [03/19/2015] Thursday
based on original concept by Mike Ransom [8/17/05] Wed

USAGE:	
	EXEC sp_RePopulate_FFY_CAES_Expenses_Using_ARC 
	@FiscalYear = 2014,
	@IsDebug = 0

---------------------------------------------------------------------
DESCRIPTION: 
TRUNCATES expenses_CAES table in order to reset idExpense, repopulates with 
data from BalanceSummaryView.

This sproc gathers expences for the Federal Fiscal Year (FFY) for 
later use in gathering SFN 201-205 expenses.
-------------------------------------------------------------------------
MODIFICATIONS:

*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_RePopulate_FFY_CAES_Expenses_Using_ARC]
--PARAMETERS: 
@FiscalYear int = 2009,
@IsDebug bit = 0

AS
declare @TSQL varchar(MAX) = ''
declare @ARCCodes varchar(max) = '';

BEGIN
-------------------------------------------------------------------------
-- Build the list of Annual Report Codes from the ARCCodes view of the 
-- ARC_Codes table
declare @temp varchar(20) = '';

declare MyCursor Cursor for select ARCCode from [FISDataMart].[dbo].[ARCCodes] for READ ONLY

open MyCursor

fetch next from MyCursor into @temp

while @@FETCH_STATUS = 0
begin
	select @ARCCodes +=  '''' + @temp + '''' 
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
-- Drop and repopulate expenses from Expenses_CAES

--Drop existing rows:
Select @TSQL = 'TRUNCATE TABLE DBO.Expenses_CAES;
'

--Repopulate:
Select @TSQL += '
INSERT INTO Expenses_CAES
	(
	FYr,
	Chart,
	Org,
	Org_R,
	Account,
	SubAccount,
	ObjConsol,
	Object,
	ExpenseSum
	)

SELECT 
	FiscalYear  FYr,
	Chart,
	OrgCode  Org,
	DepartmentLevelOrg Org_R,
	AccountNum  Account,
	SubAccount,
	ConsolidationCode ObjConsol,
	ObjectCode Object,
	Sum(Amount) ExpenseSum
FROM 
	FISDataMart.dbo.BalanceSummaryView 
WHERE 
	(
		Chart = ''3''
		AND (
				(FiscalYear =  ' + Convert(char(4), @FiscalYear) + '     AND FiscalPeriod in (''04'', ''05'', ''06'',''07'', ''08'', ''09'',''10'', ''11'', ''12'', ''13'' ))
			OR
				(FiscalYear =  ' + Convert(char(4), @FiscalYear + 1) + ' AND FiscalPeriod in (''01'',''02'',''03''))
			)
	)
	AND TransBalanceType = ''AC''
	AND ConsolidationCode Not In (''INC0'', ''BLSH'', ''SB74'')
	AND AnnualReportCode IN (' + @ARCCodes + ')
	AND CollegeLevelOrg IN (''AAES'', ''BIOS'')
	AND AccountNum NOT IN (SELECT Account FROM ArcCodeAccountExclusions WHERE Year = ' + Convert(char(4), @FiscalYear) + ')
GROUP BY 
	Chart ,
	FiscalYear ,
	OrgCode ,
	DepartmentLevelOrg,
	AccountNum ,
	SubAccount ,
	ConsolidationCode,
	ObjectCode
';
	
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
END