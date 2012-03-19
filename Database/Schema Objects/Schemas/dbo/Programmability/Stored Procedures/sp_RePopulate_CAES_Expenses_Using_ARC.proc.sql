/*
---------------------------------------------------------------------
PROGRAM: sp_RePopulate_CAES_Expenses_Using_ARC.SQL
BY:	Mike Ransom	[8/17/05] Wed

USAGE:	EXEC sp_RePopulate_CAES_Expenses_Using_ARC
	Note that FY value is hard-coded and needs to be changed each year until this is parameterized or codified.

---------------------------------------------------------------------
DESCRIPTION: 
Drops all rows from Expenses_CAES table, repopulates with pass-thru query against Oracle source FIS_DS_PROD
(18057 row(s) affected)
(3:44 minutes)

CURRENT STATUS:
[11/3/05] Thu
Added column DOC_TYPE_NUM to query, DocTypeCd to Expenses_CAES for detection of journal voucher ("JV") expenses. These are salary/benefits expenses that are not present in the PPS "TOE" table.  I could have done with a separate ...  Ah poop. I just checked; adding Doc_Type would greatly increase the size of the FIS extract. In my quick check of one account with a JV, I see 8 different Doc Types in what would otherwise be just one expense record.  I'll go back to a separate query for that detail. Initial experimentation determined that it was a very slow query (apparently Doc Type is not indexed in FIS).

NOTES:
[9/1/05] Thu: returns 18005 rows in 3:01 minutes (run at 18:00)
Accounts table needs to be up to date or ARC assignments can be wrong.
Fiscal year is hard-coded at this time, will need to be edited each year with this situation

CALLED BY:
DEPENDENCIES: 
MODIFICATIONS: see bottom
*/
-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_RePopulate_CAES_Expenses_Using_ARC]
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
Select @TSQL = 'DELETE FROM AD419.DBO.Expenses_CAES;
'

--Repopulate:
Select @TSQL += '
INSERT INTO Expenses_CAES
	(
	FYr,
	Chart,
	Org,
	Account,
	SubAccount,
	ObjConsol,
	ExpenseSum
	)

SELECT 
	FiscalYear  FYr,
	Chart,
	OrgCode  Org,
	AccountNum  Account,
	SubAccount,
	ConsolidationCode ObjConsol,
	Sum(Amount) ExpenseSum
FROM 
	FISDataMart.dbo.BalanceSummaryView 
WHERE 
	Chart = ''3''
	AND FiscalYear = ' + Convert(char(4), @FiscalYear) + '
	AND TransBalanceType = ''AC''
	AND ConsolidationCode Not In (''INC0'', ''BLSH'', ''SB74'')
	AND AnnualReportCode IN (' + @ARCCodes + ')
	AND CollegeLevelOrg IN (''AAES'', ''BIOS'')
GROUP BY 
	Chart ,
	FiscalYear ,
	OrgCode ,
	AccountNum ,
	SubAccount ,
	ConsolidationCode
';
	
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
		

-------------------------------------------------------------------------
--Delete all expenses with negative account subtotals:
--[12/7/05] Commented out after discussion with Steve. He agreed with the reasoning below.

	--(4031 row(s) affected, 2005)
	--Note: [12/7/05] I have misgivings about even doing this step.  What matters is that *Projects* doen't end up with negative associated expenses.  Project expenses can, and often do come from different accounts, plus their negative expenses (credits) on the FIS side could be offsetting expenses on the PPS (salary) side.  Also, the "PPS reversal" procedure has expenses from PPS which very closely match the FIS side; this could be thrown off if the FIS were artificially reduced (expecially if the same thing isn't done on the PPS side, which it isn't.  PPS side eliminates "negative expenses at the EID aggregation level, which also doen'st match.  Finally, on the "back side"--after user associations--I believe there is code to eliminate negative expense reporting at Project level.
	--Note: [12/7/05] Currently coded as one-way street--once deleted from Expenses_CAES, you won't be able to extract them again without re-running FIS extract.  Actually, I'm going to comment out for now the clearing out of Negative_Accounts_Archive.
	-- Note: [12/7/05]  Total is very significant: $(1,361,570.65)
	/*
	--get most recent year in deleted archive
	DECLARE @MaxYear as int
	SET @MaxYear = (SELECT MAX(FYr) from Negative_Accounts_Archive)
	set @MaxYear = isnull(@MaxYear, 2005)	--A little different from other isNull functions (i.e. nonstandard). 2nd param reqd.
		--DELETE FROM Negative_Accounts_Archive WHERE FYr LIKE @MaxYear

	--extract & archive negative accounts:
	INSERT INTO Negative_Accounts_Archive
		SELECT
			FYr,
			Account,
			sum(ExpenseSum) as Expenses
		FROM 
			Expenses_CAES
		WHERE
			FYr = @MaxYear
		GROUP BY
			FYr,
			Account
		HAVING sum(ExpenseSum) < 0
	-- Remove all expenses for negative accounts
		--Commented out until I get confirmation that we should really do this.  I don't want to.
		--DELETE FROM Expenses_CAES WHERE Account IN	(SELECT Account FROM Negative_Accounts_Archive)
	*/
END
-------------------------------------------------------------------------
/*
-- MODIFICATIONS:
 [3/29/05] Tue created

[5/3/05] Tue
Removed the following WHERE condition:
		AND Accounts.ORG_ID = Trans.ORG_ID
Experimentation with just AETX has shown that it restricts the query excessively.  One of these two tables must have missing or erronious values for the Org codes.  Steve told me today that Chart + Account was unique, and with AETX, I found this join to give the correct results.

[5/6/05] Fri:  Removed exclusion of Trans.OBJ_CONSOLIDATN_NUM = 'SUB9' per email from Steve Pesis yesterday.

 [3/30/05] MLR: works. Returns 12064 rows in 39:52 min.
[3/30/05] Wed: Works, but takes 40 minutes to run.  I was running into query timeout problems.  The Linked Server has a configurable timeout, and Query Analyzer does too (, and ODBC doesn't seem to) but I was getting a timeout in 16:02 minutes no matter what my settings in any of the above (including very short ones like a few seconds).  I experimented with using a pass-thru in Access and setting the timeout to 0 (none) and got a result in 40 minutes.  My current success is with the Linked Server timeout set to 0 and Query Analyzer set to 6000 (from default of 600).  I'm not sure if I changed both of those at the same time, but the Q/A setting was the last one I made.  I'll have experiment with the linked server timeout, but I think it must have been 0--the other linked servers defined on AgDean16/Devel are set to 0, so I think that wasn't the problem. The L/S timeout might be a restriction in addition to the Q/A timeout.  For now, the conclusion is that with Q/A set to 600 seconds or 0, it would still time out at 16 minutes.  Another possibility is that fis_ds_prod (the Oracle source) switches timeout settings after 5:00 p.m. (it ran from 4:50 to 5:30).

 [8/17/05] MLR: Edited to FY 2005, run.  11610 rows in 49:34

[8/25/05] Thu: got a lot of expenses with blank Org_IDs. Began to get suspicious of this being similar to problem I'd had before; investigation found that the join condition "AND Accounts.ORG_ID = Trans.ORG_ID" had somehow gotten back into the query.  Trying again...

[8/31/05] MLR: changed to year=2005 and period='--' for Accounts & Org tables.
Changed order of WHERE clause conditions.
Changed all tables to explicit chart value (3) rather then equality. (should be faster, same results)

 [9/1/05] Thu: 
	-- using 2005 and 9999 both return identical results.
	-- Problem: Returns expenses for legacy Plant Sciences depts. (as well as PLS). Sched C doesn't)

	-- [9/2/05] Fri: Working fine.  Found that Accounts table needs to be up to date or ARC assignments can be wrong.

 [9/6/05] Tue:
	-- Removed SUB9 (Recharges) from Object Consolidation filter.
	-- Line was: Trans.OBJ_CONSOLIDATN_NUM Not In (''INC0'', ''BLSH'', ''SB74'', ''SUB9'')
	-- Returned 45 more records. It's exactly same as Sched C now (to penny) for 24/32 ARCs and within .2% overall.

[9/20/05] Tue:
	Ran 1st time on production copy--it still had last year's data, so the 204 extract was wrong.
	(17066 row(s) affected)
	(18050 row(s) affected)
	(4:06 minutes)

[10/20/05] Thu 
Added ARC 440200 for "Air Shuttle Service" per Steve Pesis-he sez this is used for things other than the air shuttle now which are legit research activities. Note that this is an exception in that all other ARCs used are in Schedule C--this one is not.  Extracts an additional 7 rows.

[09/14/2009] by KJT:
Added parameter for year, plus query for retrieving ARC Codes, plus use of FISDataMart trans, Organizations, and Accounts tables.

*/
