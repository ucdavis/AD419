/*
PROGRAM: sp_Repopulate_Acct_SFN
BY:	Mike Ransom	(all comments Mike's unless otherwise noted)
USAGE:	(run from within AD419 DB. (accesses Account table in FIS DB)

		Execute sp_Repopulate_Acct_SFN

DESCRIPTION: 

Repopulates table Acct_SFN.  This table contains the Chart + Org + Account_ID for all accounts in the Account table which have ARCs (Annual Reporting Codes) in Schedule C.  Association with Sched C report is determined by flagging field ARC_Codes.isAES (if =1 then associated).  Acct_SFN serves to store what the SFN (Source of Funds Number) of each account are.  It further serves to validate all Account SFN classifications by virtue of additional columns which store info on how many SFNs the account attributes matched, which SFNs and what order these were met in the classification program.  By querying this table, we can instantly tell if any accounts didn't get and SFN classifications, or which met the criteria for more than one SFN. This helps emensely in evaluating the SFN classification rules, which has been a major headache in the past.


CURRENT STATUS:
[9/7/06] Thu
Trying out as I start on the 05-06 cycle

[10/24/07] SRK
Starting 06-07 cycle

NOTES:
Some maintenance may be required in future if the ARCs in Schedule C are changed (added or removed).

Both Account and ARC_Codes tables are in the FIS database. Table aliasing was required since I had an ARC_Codes table in AD419 DB also. I've deleted it.


MODIFICATIONS: see bottom
CALLED BY:
DEPENDENCIES: 
	Accounts table in FIS DB needs to be up to date (no automated maintenance procedure as of now--9/7/06)
	FIS.dbo.ARC_Codes would also need to be up-to-date, tho I assume that's nearly static.

*/
CREATE procedure [dbo].[sp_Repopulate_Acct_SFN]
--PARAMETERS:
@FiscalYear int = 2009, -- Fiscal Year.
@IsDebug bit = 0 -- Set to 1 to just print SQL, and not actually run sproc.
AS

declare @TSQL varchar(MAX)	= '' --Holds T-SQL code to be run with EXEC() function.

BEGIN

SET NOCOUNT ON	-- to prevents extra result sets from interfering with SELECT statements.

-------------------------------------------------------------------------
--Clear Chart 3 Schedule C - based Accounts from table:
print '--Clearing previous records from Acct_SFN...'
select @TSQL = 'DELETE FROM Acct_SFN'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
print '--Deleted ' + convert(varchar,@@RowCount) + ' records.'

--Repopulate
print '--Inserting new records...'

select @TSQL = 'INSERT INTO Acct_SFN ( chart, org, acct_id, isCE )
	SELECT DISTINCT Account.Chart,
 Account.Org,
  Account.Account, 
(CASE WHEN ((LEFT(Account.A11AcctNum,2) BETWEEN ''44'' AND ''59'') OR Account.HigherEdFuncCode = ''ORES'') AND Account.Chart = ''L'' THEN 1
	  WHEN ((LEFT(Account.A11AcctNum,2) = ''62'' OR Account.HigherEdFuncCode = ''PBSV'') ) THEN 1
	  ELSE 0 END) 
 AS isCE
	FROM         [FISDataMart].[dbo].[Accounts] Account LEFT OUTER JOIN
						   [FISDataMart].[dbo].[ARCCodes] ARC_Codes ON Account.AnnualReportCode like ARC_Codes.ARCCode
						   where  Year = ' + CONVERT(char(4), @FiscalYear) + ' AND Period = ''--''
						   AND Account.HigherEdFuncCode not like ''PROV'' -- Exclude the PROV accounts.
						   order by Chart, Account.Account, Account.Org, isCE	  
	'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
print '--Inserted ' + convert(varchar,@@RowCount) + ' records.'
print '-------------------------------------------------------------------------'


-------------------------------------------------------------------------
PRINT '-------------------------------------------------------------------------'
PRINT '--Running SFN classification procedure...'

select @TSQL = 'EXECUTE sp_SFN_Classify @FiscalYear = ' + CONVERT(char(4), @FiscalYear) + ', @IsDebug =' + CONVERT(char(1), @IsDebug)
if @IsDebug = 1
		begin
			Print @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
END
-------------------------------------------------------------------------
/* [9/11/06] MLR NOTE: AT THIS POINT, INSPECTION OF UNCLASSIFIED OR MULTIPLY (AMBIGUOUSLY) CLASSIFIED ACCOUNTS IS KEY TO ENSURING THAT EXPENSES EXTRACTED FOR AD419 ARE ALL PROPERLY CLASSIFIED.

I CURRENTLY HAVE A FEW QUERIES IN ACCESS FOR THIS INSPECTION, BUT NO SPROCS/VIEWS.  THIS WOULD BE GOOD TO INCLUDE IN ANY ADMIN INTERFACE.
*/

/*
-------------------------------------------------------------------------
MODIFICATIONS:

[9/7/05] Wed: Created.  Revisiting after long interruption working with this. Found a query in Access that repopulated, but nothing to clear old table. This on combines both.
[9/11/06] Mon: 
	* Updated FY to 2006 in Chart L section. 
	* Minor changed in PRINT output (using @@RowCount)
	* Incorporated call to sp_SFN_Classify, since it is essential for validating results of Acct_SFN repopulation
[10/25/2010]: by kjt: Added code to pass @FiscalYear as parameter to call to execute sp_SFN_Classify.

USAGE:	(run from within AD419 DB. (accesses Account table in FIS DB)

		Execute sp_Repopulate_Acct_SFN

*/
