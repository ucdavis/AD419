------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_FIS_Expenses
BY:	Mike Ransom
DESCRIPTION: 

CURRENT STATUS:
[11/6/06] Mon 11:58
	Appears to be working.
NOTES:
(5193 row(s) affected), 39 sec.

DEPENDENCIES:
	udf_Adjusted_FIS_Expenses

TODO:
[11/29/05] Tue
	* All the separate queries merging lookup values from different tables could be consolidated into 1 query.
	* Some of these UPDATEs may be better done globally after the other merges, eg stuff related to Accounts, sub-account, PI, SFN.
	Title table is still old Foxpro structure, may get revamped someday.
	* [11/6/06] Mon 
		Note on last: No, better to do denormalizing update independently for each datasource. This allows separate updates for each datasource. Performance not an issue. Maintenance of code would be simpler, but losing the ability for independent repop is more important.
	
	* Need to drop expenses for Accounts with total expenses that are negative?
		SELECT DISTINCT AD419_Expenses_Dataset.org_3, AD419_Expenses_Dataset.acct_id, AD419_Expenses_Dataset.chart, Sum(AD419_Expenses_Dataset.expend) AS SumOfexpend
		FROM AD419_Expenses_Dataset
		GROUP BY AD419_Expenses_Dataset.org_3, AD419_Expenses_Dataset.acct_id, AD419_Expenses_Dataset.chart
		HAVING (((Sum(AD419_Expenses_Dataset.expend))<0))
		[11/6/06] Mon Think we decided no, which was a change from previous (Ken's algorythm). What really matters is that we don't report a negative expense at the OrgR x Project x SFN level.

--USAGE:	
	EXECUTE sp_Repopulate_AD419_FIS_Expenses

MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_FIS_Expenses] (
@FiscalYear int = 2009,
@IsDebug bit = 0
)
AS

BEGIN
declare @TSQL varchar(MAX) = null
-------------------------------------------------------------------------
BEGIN TRANSACTION
-------------------------------------------------------------------------
	--Delete all FIS-sourced expense records:
	PRINT 'DELETE FROM AllExpenses WHERE DataSource = ''FIS''...'
	Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = ''FIS''; '
	
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
-------------------------------------------------------------------------
	--Insert adjusted expenses from FIS.  (from udf_Adjusted_FIS_Expenses())
		-- udf_Adjusted_FIS_Expenses() produces a dataset that's a UNION of FIS expenses + FIS Reversals.  The sign of the "reversal" amounts are changed in the UDF so that they can be SUMmed here.
	PRINT 'Inserting adjusted FIS expenses...'
	
	Select @TSQL= 'INSERT INTO AllExpenses
		(
		DataSource,
		Chart,
		OrgR,
		Account,
		SubAcct,
		Expenses,
		isNonEmpExp,
		EID,
		Employee_Name,
		isAssociated,
		isAssociable,
		PI_Name,
		Org,
		Exp_SFN,
		Sub_Exp_SFN
		)
		(
		SELECT 
			''FIS'',
			E.Chart,
			Org_R,
			E.Account,
			SubAccount,
			sum(Expend)	Expenses,
			1	isNonEmpExp,
			NULL	EID,
			NULL	Employee_Name,
			0	isAssociated,
			1	isAssociable,
			PrincipalInvestigatorName	PI_Name,
			A.Org,
			LEFT(SFN.SFN,3) Exp_SFN	,
			SFN.SFN	Sub_Exp_SFN
		FROM udf_Adjusted_FIS_Expenses() E
			LEFT JOIN FISDataMart.dbo.Accounts A ON 
				E.Account = A.Account
				AND A.Year = ' + CONVERT(char(4), @FiscalYear) + '
				AND A.Period = ''--''
				AND E.Chart = A.Chart
			LEFT JOIN Acct_SFN as SFN ON
				E.Account = SFN.Acct_ID
				AND E.Chart = SFN.Chart
				AND A.Year = ' + CONVERT(char(4), @FiscalYear) + '
				AND A.Period = ''--''
		WHERE 
			LEFT(SFN.SFN,3) NOT IN (''201'',''202'',''203'',''204'',''205'')
		GROUP BY E.chart, Org_R, E.Account, SubAccount, PrincipalInvestigatorName, A.Org, LEFT(SFN.SFN,3), SFN.SFN
		HAVING sum(Expend) <> 0
		)
		
DELETE FROM AllExpenses
WHERE     (OrgR IS NULL) AND DataSource = ''FIS''

UPDATE    AllExpenses
SET              SubAcct = NULL
WHERE     (SubAcct = ''-----'') AND DataSource = ''FIS''

UPDATE    AllExpenses
SET              FTE = 0
WHERE     (FTE IS NULL) AND DataSource = ''FIS''

UPDATE    AllExpenses
SET              FTE_SFN = ''244'', Staff_Grp_Cd = ''Other''
WHERE     (Staff_Grp_Cd IS NULL) AND DataSource = ''FIS'' 
;'

	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
-------------------------------------------------------------------------
COMMIT TRANSACTION
-------------------------------------------------------------------------
END
/*
MODIFICATIONS:

[11/22/05] Tue
	Created last week.

[11/6/06] Mon
	* Modified to work with the (new) final Expenses table. (some columns were eliminated, some renamed, and Expenses is the table the UI runs against)
	* Modified to be transactional. 
	* Commented out sections/columns no longer needed. (Probably delete after this year's report.)
	
[12/17/2010] by kjt:
	Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.

-------------------------------------------------------------------------
--USAGE:	
	EXECUTE sp_Repopulate_AD419_FIS_Expenses

*/
