------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_PPS_Expenses
BY:	Mike Ransom
DESCRIPTION: 

CURRENT STATUS:
[11/15/06]
	* Added Org back into SELECT INTO statement, since it will be needed as one of the groupings
[11/7/06] Tue
	* Refactored for changes in data structure for 2006.
	* Modified to insert records directly into AllExpenses, the table which the UI runs against. (eliminated intermediate table Expenses_PPS)
	* Added transaction to delete/insert

TODO:
[11/29/05] Tue
	* All the separate queries merging lookup values from different tables could be consolidated into 1 query.
	* All the UPDATEs filling in "blank" or "-----" type values could also be consolidated by using UNION constructs to bring in the values where they don't exist in tables.
	* Some of these UPDATEs may be better done globally after the other merges, eg stuff related to Accounts, sub-account, PI, SFN.
	Title table is still old Foxpro structure, may get revamped someday.

[11/30/05] Wed
Staff_type is currently stored in PPS.dbo.Title and is not programmatically maintained.  (Neither is the Fox TitleCd table that the PPS datamart uses, and Title is based on and originally populated from TitleCd.)  For this reason, new titles appeared in the TOE extract and didn't resolve.  A maintenance proc is needed for both Title table and probably a UI for coding them to staff_type.  The data structure is a messed up design from Ken with codes 1S, 2P, 3T, 4C for Scientist, Professional, Technical and Clerical/Other. The number is simply for sorting purposes.


NOTES:
8585 row(s), total time 42 sec.  ([11/29/05] Tue)

--USAGE:	
	EXECUTE sp_Repopulate_AD419_PPS_Expenses

DEPENDENCIES:

MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_PPS_Expenses]
( 
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
declare @TSQL varchar(MAX) = null;

BEGIN
-------------------------------------------------------------------------
BEGIN TRANSACTION
-------------------------------------------------------------------------
--Delete all PPS-sourced expense records:
Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = ''PPS'''
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end

-------------------------------------------------------------------------
--Insert adjusted expenses from PPS.  (from Expenses_PPS_Adjusted())
Select @TSQL = 'INSERT INTO AllExpenses
	(
	DataSource,
	Chart,
	OrgR,
	Account,
	SubAcct,
	EID,
	Employee_Name,
	TitleCd, 
	Title_Code_Name,
	Expenses,
	isNonEmpExp,
	isAssociated,
	isAssociable,
	Org,
	fte_sfn, 
	FTE,
	PI_Name,
	Exp_SFN,
	Staff_Grp_Cd
	)
	(
	SELECT 
		''PPS''	DataSource, 
		''3''	Chart,
		E.Org_R	OrgR, 
		E.Account, 
		E.SubAccount	SubAcct, 
		E.Employee_ID	EID, 
		E.TOE_Name	Employee_Name, 
		E.TitleCd	TitleCd, 
		left(T.Name,3)	Title_Code_Name,
		sum(E.PPS_Expense)	Expenses, 
		0	isNonEmpExp,
		0	isAssociated,
		1	isAssociable,
		A.Org,
		E.fte_sfn, 
		sum(E.FTE) FTE,
		A.PrincipalInvestigatorName PI_Name,
		left(SFN.SFN,3) Exp_SFN,
		E.Staff_Type
	FROM Expenses_PPS_Adjusted E	/* view */
		LEFT JOIN FISDataMart.dbo.Accounts A ON 
			E.Account = A.Account
			AND A.Chart =''3''
			AND A.Year = ' + Convert(char(4), @FiscalYear) + '
			AND A.Period = ''--''
		LEFT JOIN Acct_SFN SFN ON
			A.Account = SFN.Acct_ID
			AND SFN.Chart = ''3''
			AND A.Year = ' + Convert(char(4), @FiscalYear) + '
			AND A.Period = ''--''
		LEFT JOIN PPSDataMart.dbo.Titles T ON 
			E.TitleCd = T.TitleCode
	GROUP BY 
		Org_R, E.Account, SubAccount, Employee_ID, TOE_Name, E.TitleCd, A.Org, fte_sfn, PrincipalInvestigatorName, left(SFN.SFN,3), T.Name, E.Staff_Type
	HAVING  sum(PPS_Expense) <> 0
	)'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
-------------------------------------------------------------------------
--Drop (zero out) expenses of CSREES accounts, but leave all other columns:
	--(436 row(s) affected)
Select @TSQL = 'UPDATE AllExpenses 
SET Expenses = 0 
WHERE 
	Exp_SFN in (''201'',''202'',''203'',''204'',''205'')
	AND DataSource = ''PPS''

--Eliminate expenses records that have both 0 $ and 0 FTE
DELETE FROM AllExpenses
WHERE 
	Exp_SFN in (''201'',''202'',''203'',''204'',''205'')
	AND DataSource = ''PPS''
	AND (Expenses=0 AND FTE=0)

DELETE FROM AllExpenses
WHERE     (OrgR IS NULL) AND DataSource = ''PPS''

UPDATE    AllExpenses
SET              SubAcct = NULL
WHERE     (SubAcct = ''-----'') AND DataSource = ''PPS''

UPDATE    AllExpenses
SET              FTE = 0
WHERE     (FTE IS NULL) AND DataSource = ''PPS''

UPDATE    AllExpenses
SET              FTE_SFN = ''244'', Staff_Grp_Cd = ''Other''
WHERE     (Staff_Grp_Cd IS NULL) AND DataSource = ''PPS''
'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end
-------------------------------------------------------------------------
COMMIT TRANSACTION
-------------------------------------------------------------------------
END
/*
-------------------------------------------------------------------------
CALLED BY:

DEPENDENCIES:

MODIFICATIONS:
[11/30/05] Wed
	Finished.  Was working yesterday, but the results showed that some of the title codes were not classified as to staff_type.  Took care of that and re-ran.

[11/29/05] Tue
	Created, based on sp_Repopulate_AD419_FIS_Expenses.

[12/27/05] Tue
	* Modified, mostly just formatting, in prep for separating benefits from wages, but we backed off from that even tho we should probably do it next year. Code for that is in sp_Repopulate_AD419_PPS_Expenses2.sql
	Changed from doing a separate UPDATE for the columns Chart, Associated,	Asscbl, NonEmpExp to doing in initial INSERT.
[11/7/06] Tue
	* Refactored for changes in data structure for 2006.
	* Modified to insert records directly into Expenses, the table which the UI runs against. (eliminated intermediate table Expenses_PPS)
	* Added transaction to delete/insert
	
[12/17/2010] by kjt:
	Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
 
--USAGE:	
	EXECUTE sp_Repopulate_AD419_PPS_Expenses


*/
