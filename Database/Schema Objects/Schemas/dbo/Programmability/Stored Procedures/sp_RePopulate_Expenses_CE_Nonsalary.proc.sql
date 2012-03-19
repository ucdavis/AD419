/*
---------------------------------------------------------------------
PROGRAM: sp_RePopulate_Expenses_CE_Nonsalary.SQL
BY:	Mike Ransom	[8/17/05] Wed

USAGE:	

	EXEC sp_RePopulate_Expenses_CE_Nonsalary
	

---------------------------------------------------------------------
DESCRIPTION: 
Drops all rows from sp_RePopulate_Expenses_CE_Nonsalary table, repopulates with pass-thru query against Oracle source FIS_DS_PROD
(8565 row(s) affected)
(2:43 minutes)

CURRENT STATUS:
	[12/12/05] Mon


NOTES:
	[12/9/05] Fri
Repopulates Expenses_CE_Nonsalary (Cooperative Extension non-salary expenses).  Can't use ARC codes as for the AES (Chart 3) expenses, as Chart 3 doesn't cover

Doesn't exclude SUB9 (recharges) as Fox program did--same as we did in Chart 3 extract (based on ARC).

Fiscal year is hard-coded at this time.



CALLED BY:
DEPENDENCIES: 
MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_RePopulate_Expenses_CE_Nonsalary]
--PARAMETERS: none
( 
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
BEGIN
declare @TSQL varchar(MAX) = null;
-------------------------------------------------------------------------
-- Drop and repopulate expenses from Expenses_CE_Nonsalary

--Drop existing rows:
Select @TSQL = 'DELETE FROM Expenses_CE_Nonsalary'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end

--Repopulate:
Select @TSQL = 'INSERT INTO Expenses_CE_Nonsalary
	(
	Chart,
	Org,
	Account,
	SubAccount,
	Expend
	)
SELECT * FROM
	OPENQUERY 
		(FIS_DS,
		''
SELECT 
	Trans.CHART_NUM Chart,
	Trans.ORG_ID Org,
	Trans.ACCT_NUM Account,
	Trans.SUB_ACCT_NUM SubAccount,
	Sum(Trans.TRANS_LINE_AMT) ExpenseSum
FROM 
	FINANCE.ORGANIZATION_ACCOUNT  Accounts,
	FINANCE.GL_APPLIED_TRANSACTIONS  Trans
WHERE 
	(
		Accounts.ACCT_NUM = Trans.ACCT_NUM
		AND Accounts.CHART_NUM = ''''L''''
		AND Accounts.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + ' 
		AND Accounts.FISCAL_PERIOD = ''''--'''' 
	)
	AND Trans.CHART_NUM = ''''L''''
	AND Trans.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + '
	AND Trans.BALANCE_TYPE_CODE = ''''AC''''
	AND Trans.OBJ_CONSOLIDATN_NUM Not In (''''INC0'''', ''''BLSH'''', ''''SB74'''')
	AND Accounts.HIGHER_ED_FUNC_CODE IN (''''ORES'''',''''PBSV'''')
GROUP BY 
	Trans.CHART_NUM ,
	Trans.ORG_ID ,
	Trans.ACCT_NUM,
	Trans.SUB_ACCT_NUM
		'')
		;'
		
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
		
/* [11/3/06] Fri Object Consolidation removed. No longer exists in Expenses_CE_Nonsalary, so I'm assuming that it wasn't needed.
	obj_cnsld,
	Trans.OBJ_CONSOLIDATN_NUM ObjConsol,
	Trans.OBJ_CONSOLIDATN_NUM
*/

END
-------------------------------------------------------------------------
/*
MODIFICATIONS:
	[12/9/05] Fri
Created.
Is only returning 21 records under Org BREP.  Something's wrong with this.

	[12/12/05] Mon:

Removed [12/12/05] Mon:
	AND Orgs.ORG_ID_LEVEL_1 IN (''AAES'', ''BIOS'')
		
	AAES actually is at Level 2 for Chart L stuff. But also, there aren't many more orgs outside of level 2 'AAES', so I'm just going to include all cht L.

Now is
(8565 row(s) affected)
(2:43 minutes)

*/
