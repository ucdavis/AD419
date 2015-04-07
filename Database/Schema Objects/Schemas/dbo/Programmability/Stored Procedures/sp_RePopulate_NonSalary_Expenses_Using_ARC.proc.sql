/*
---------------------------------------------------------------------
PROGRAM: sp_RePopulate_NonSalary_Expenses_Using_ARC.SQL
BY: Ken Taylor on 2012-11-19

USAGE:	EXEC sp_RePopulate_NonSalary_Expenses_Using_ARC

---------------------------------------------------------------------
DESCRIPTION: 
Drops all rows from Expenses_CAES table,

CURRENT STATUS:

NOTES:

CALLED BY: sp_Repopulate_AD419_All

DEPENDENCIES: FISDataMart must be current and ARC Codes table must be configured for current year.

MODIFICATIONS:
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_RePopulate_NonSalary_Expenses_Using_ARC]
--PARAMETERS: 
@FiscalYear int = 2012,
@IsDebug bit = 0

AS
declare @TSQL varchar(MAX) = ''
declare @ARCCodes varchar(max) = '';

BEGIN
---------------------------------------------------------------------------
-- Drop and repopulate expenses from FIS_NonSalaryExpenses

--Drop existing rows:
Select @TSQL = 'TRUNCATE TABLE FIS_NonSalaryExpenses;
'

--Repopulate:
Select @TSQL += '
INSERT INTO FIS_NonSalaryExpenses
	(
	FYr,
	Chart,
	Org,
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
	AccountNum  Account,
	SubAccount,
	ConsolidationCode ObjConsol,
	ObjectCode Object,
	Sum(Amount) ExpenseSum
FROM 
	FISDataMart.dbo.BalanceSummaryView INNER JOIN
	FISDataMart.dbo.ARCCodes ON AnnualReportCode = ARCCode
WHERE 
	Chart = ''3''
	AND FiscalYear = ' + Convert(char(4), @FiscalYear) + '
	AND TransBalanceType = ''AC''
	AND ConsolidationCode Not In (''INC0'', ''BLSH'', ''SB74'')
	AND (ConsolidationCode NOT IN (
			''ACAD'',
			''ACGA'',
			''SB01'',
			''SB02'',
			''SB03'',
			''SB04'',
			''SB05'',
			''SB06'',
			''SB07'',
			''SB28'',
			''SCHL'',
			''STFB'',
			''STFO'',
			''SUB0'',
			''SUB3'',
			''SUB6'',
			''SUBG'',
			''SUBS''
			) 
		OR 
			(TransDocType NOT IN(''SET'', ''BET'', ''YSET'', ''YBET'', ''RETR'',''OPAY'', ''HDRW'', ''PAY'')
		)
	)
	AND CollegeLevelOrg IN (''AAES'', ''BIOS'')
GROUP BY 
	Chart ,
	FiscalYear ,
	OrgCode ,
	AccountNum ,
	SubAccount ,
	ConsolidationCode,
	ObjectCode
';
	
	if @IsDebug = 1
		begin
			SET NOCOUNT ON
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
END