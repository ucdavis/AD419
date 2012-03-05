------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_CE_NonSalary_Expenses
BY:	Scott Kirkland, Mike Ransom
USAGE:

	EXECUTE sp_Repopulate_AD419_CE_NonSalary_Expenses

DESCRIPTION: 

CURRENT STATUS:
	[11/8/06] SRK -- Changed sproc to use the Expenses table directly, where the DataSource = 'CENS'.  The account table is now joined with
				a combination of the PIName and Chart ('L') because there is no 'Account' information along with the CEs.
	[12/22/05] Thu
* Corrected Org_R (Org_3 in current AD419 structure) from using Org_3 to Org_4. (This had been done in population of AD419_Reporting_Org, but I missed it here, as I was templating off of PPS or FIS repopulate code.)
* Changed that: linked to AD419_Reporting_Org to get Org_R. Found that (lev 4) AHCH was not valid by the other way. (changed to AHCD in sp_Repopulate_AD419_Reporting_Org)
* Changed to getting Org Name in the initial INSERT instead of one of the UPDATEs below (was linking to Organization already).


TODO:


NOTES:

DEPENDENCIES, CALLED BY, and MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_CE_NonSalary_Expenses]
AS
-------------------------------------------------------------------------
BEGIN

--Delete all FIS-sourced expense records:
DELETE FROM AllExpenses WHERE DataSource = 'CENS'
-------------------------------------------------------------------------
--Insert expenses from raw CE Non-salary extract, adding additional (denormalized) column values:
	--[12/13/05] Tue: (155 row(s) affected)
/*
INSERT INTO AD419_Expenses_Dataset
	(
	DataSource,
	Chart,
	Org_3,
	Org,
	Org_Name,
	acct_id,
	sub_acct,
	exp_SFN,
	Expend
	)
	*/
	
	INSERT INTO AllExpenses
	(
	DataSource,
	Chart,
	OrgR,
	Org,
	Account,
	SubAcct,
	PI_Name,
	Exp_SFN,
	EID,
	Employee_Name,
	Expenses,
	FTE,
	isAssociated,
	isAssociable,
	isNonEmpExp
	)
	SELECT 
		'CENS' AS DataSource, 
		'L' AS Chart, 
		RO.OrgR,
		RO.Org, 
		--O.Org_Name,
		CENS.Account, 
		CENS.SubAccount AS SubAcct,
		C.AccountPIName AS PI_Name,
		--CE.SubAccount,
		left(SFN.SFN,3) AS exp_sfn,
		'nonempexp' AS EID,
		' CE Non-salary Expense' AS Employee_Name,
		CENS.Expend AS Expenses,
		0 AS FTE,
		'0' AS isAssociated,
		'1' AS isAssociable,
		'1' AS isNonEmpExp
	FROM CESXProjects AS CE
		INNER JOIN CESList AS C ON
			C.EID = CE.EID
		INNER JOIN OrgXOrgR RO ON
			CE.OrgR = RO.OrgR
			AND RO.Chart = 'L'
		INNER JOIN FISDataMart.dbo.Accounts AS A ON
			A.Chart = 'L'
			AND C.AccountPIName = A.PrincipalInvestigatorName
		INNER JOIN Expenses_CE_Nonsalary AS CENS ON
			CENS.Chart = 'L'
			AND CENS.Account = A.Account
			AND CENS.Org = RO.Org
		LEFT JOIN FISDataMart.dbo.Organizations AS O ON
			RO.Org = O.Org
			AND O.Chart = 'L'
		LEFT JOIN Acct_SFN AS SFN ON 
			A.Account = SFN.Acct_ID
			AND SFN.Chart = 'L'
	WHERE
		--C.IfInclude <> 0 AND [IfInclude is currently null -- next time need to include this in CE Entry]
		left(SFN.SFN,3) NOT IN ('201','202','204','205')
	ORDER BY A.Account
		

-------------------------------------------------------------------------
--Update columns (semi-) specific to FIS source:

--Asscbl, NonEmpExp, ID, Name (Not dependent on other tables)
/*
UPDATE AD419_Expenses_Dataset
SET 
	Associated = 0,
	Asscbl=1, 
	NonEmpExp=1, 
	ID='nonempexp', 
	[Name]=' CE Non-salary Expense'
WHERE DataSource = 'CENS'
*/
/*
UPDATE    Expenses
SET         isAssociated = 0, 
			isAssociable = 1, 
			isNonEmpExp = 1
WHERE     (DataSource = 'CENS')
*/
-------------------------------------------------------------------------
--Update columns dependent on other tables (denormalization)

--From Accounts table (in DB FIS)
	-- Account Name
	-- exp_sfn
	-- PI
	--Org_3 Name (Representing Org_R, and to be updated below where Org_3 is blank)
	-- Org_Name
	/*
UPDATE AD419 
SET 
	AD419.acct_name = Account.Account_Name, 
	AD419.PI = Account.Principal_Investigator_Name,
	AD419.Exp_SFN = left(SFN.SFN,3)
FROM 
	AD419_Expenses_Dataset as AD419 
		LEFT JOIN FIS.dbo.Account as Account ON 
			AD419.acct_id = Account.Account_Num
			AND Account.Chart ='L'
			LEFT JOIN Acct_SFN as SFN ON
				Account.Account_Num = SFN.Acct_ID
				AND SFN.Chart = 'L'
	WHERE
		AD419.DataSource = 'CENS'
		*/
----------------
--Blank PI (Those that are still null after above coding)
	--Note: must follow UPDATE of PI above
	--[12/13/05] Tue (0 row(s) affected)
	/*
UPDATE AD419 
SET 
	AD419.PI = 'Blank PI'
FROM 
	AD419_Expenses_Dataset as AD419
WHERE 
	DataSource = 'CENS'
	AND AD419.PI IS NULL
*/
--From SubAccount Table (SubAccount Name)
/*
UPDATE AD419 
SET 
	AD419.subacct_nm = SubAcct.SubAccount_Name
FROM 
	AD419_Expenses_Dataset as AD419 
		LEFT JOIN FIS.dbo.SubAccount as SubAcct ON 
			AD419.Sub_Acct = SubAcct.SubAccount_Num
			AND SubAcct.Chart ='L'
	WHERE
		AD419.DataSource = 'CENS'
		*/
----------------
--Update SubAccount, SubAccount Name for null subaccount:
/*
UPDATE AD419_Expenses_Dataset  
SET 
	Sub_Acct = '-----',
	subacct_nm = 'Default Sub Account'
WHERE
	DataSource = 'CENS'
	AND Sub_Acct IS NULL
*/
	
UPDATE    AllExpenses
SET              SubAcct = NULL
WHERE     (DataSource = 'CENS') AND (SubAcct = '-----')
-------------------------------------------------------------------------
--Update Org_3 with Org_2 where former null, latter non-null:
	--(0 row(s) affected)
	/*
UPDATE AD419_Expenses_Dataset
SET Org_3 = Org_2
FROM
	AD419_Expenses_Dataset as AD419 
		LEFT JOIN FIS.dbo.Organization as Org ON
			Org.Org = AD419.Org
			AND Org.Chart = 'L'
	WHERE
		AD419.DataSource = 'CENS'
		AND 
			(
			Org.Org_3 IS NULL
			AND Org.Org_2 IS NOT NULL
			)
	*/
END
-------------------------------------------------------------------------
/*
CALLED BY:

DEPENDENCIES:

MODIFICATIONS:

	[3/12/2010] Fri by Ken Taylor.
Modified sproc to use FISDataMart database Accounts and Organizations tables instead of
now defunct FIS database.
Note: This sproc and the Expenses_CE_Nonsalary table were not used in the 2009 AD-419
Annual Reporting process as there were no non-salary CE expenses according to Steve Pesis.
	[12/21/05] Wed
Added line:
		AND left(SFN.SFN,3) NOT IN ('201','202','204','205')
to WHERE clause.
204 expenses should be zeroed here, just as they were in the FIS/PPS inputs. They are covered 100% by our separate 201-205 inputs.
--Actually, maybe not. 201,2,5 might be covered by CeCe's data entry, but the 204's not. We probably need to do 204-to-project associations for CE just like we did for AES expnses.  
[12/22/05] Thu CeCe indicates all CSREES expenses are accounted for in her data entry. We can drop the CSREES expenses from the CE.


	[12/13/05] Tue
Finished.
	[12/12/05] Mon
Created

[12/17/2010] by kjt:
	Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.

*/
