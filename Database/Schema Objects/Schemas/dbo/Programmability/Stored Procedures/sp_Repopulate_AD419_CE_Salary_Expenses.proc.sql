------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_CE_Salary_Expenses
BY:	Mike Ransom

USAGE:

	EXECUTE sp_Repopulate_AD419_CE_Salary_Expenses


DESCRIPTION: 

CURRENT STATUS:
	[1/12/06] Thu
Modified link to SubAccounts table to include Account_Num equality.
	(Without this, quite a number of duplicates were being created (on the order of up to 9).)
Changed from getting Org_3 from Organization to AD419_Reporting_Org.
Changed link to Org info to go via CE Account --> Accounts --> AD419_Reporting_Org.
	(This because the value for Org from PPS table was found not to be the Org code, but something normalized to Org_3 or something. The value of Org in Accounts is reliable and correct, however.

	[12/15/05] Thu
Finished.
	[12/13/05] Tue
Created

TODO:

	NOTES:
Requires running two queries in Access to populate the source table here:
	[CE Extract Payroll Salary Expenses from PPS] and
	[CE Extract Payroll Other Expenses from PPS]
This is because the FTE column calculation would be messed up when it multiplied the PPS PAID_PCT column by the Pct_Effort--it would send it to 0 when it should = Pct_Effort.


DEPENDENCIES, CALLED BY, and MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_CE_Salary_Expenses]
(
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
-------------------------------------------------------------------------
BEGIN
DECLARE @TSQL varchar(MAX) = null


--Delete all FIS-sourced expense records:
--PRINT 'Deleting previous CES records...'
Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = ''CES''
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
--Insert expenses from raw CE Non-salary extract, adding additional (denormalized) column values:
	--[12/13/05] Tue: (155 row(s) affected)
PRINT 'Inserting new CES records...'
/*
INSERT INTO AD419_Expenses_Dataset
	(
	DataSource,
	Chart,
	Org_3,
	Org,
	Org_Name,
	acct_id,
	acct_name,
	sub_acct,
	subacct_nm,
	exp_SFN,
	PI,
	ID,
	Name,
	Title,
	title_name,
	staff_grp,
	Expend,
	FTE,
	fte_sfn
	)
	*/
	Select @TSQL = 'INSERT INTO AllExpenses
	(
		DataSource,
		Chart,
		OrgR,
		Org,
		Account,
		SubAcct,
		Exp_SFN,
		PI_Name,
		EID,
		Employee_Name,
		TitleCd,
		Title_Code_Name,
		Staff_Grp_Cd,
		Expenses,
		FTE,
		FTE_SFN,
		isAssociated, 
		isAssociable, 
		isNonEmpExp
	)	
	SELECT 
		''CES'' AS DataSource, 
		''L'' AS Chart,
		O.OrgR,
		A.Org as Org, 
		--O.OrgR_Name,
		A.Account AS Account,
		--A.Account_Name,
		NULL AS SubAcct,
		--SubAcct.SubAccount_Name as subacct_nm,
		left(SFN.SFN,3) AS exp_SFN,
		CESLIST.AccountPIName AS PI_Name,
		CE.EID,
		''(CE PI) '' + CESLIST.AccountPIName AS Employee_Name,
		CESLIST.Title_Code AS TitleCd,
		left(Title.Name,35) AS Title_Code_Name,
		Staff_Type.Staff_Type_Short_Name AS staff_grp,
		SUM(CE.CESSalaryExpenses) / 
		(
			SELECT COUNT(A.PrincipalInvestigatorName)
			FROM FISDataMart.dbo.Accounts AS A
			WHERE ''L'' = A.Chart
					AND CESLIST.AccountPIName = A.PrincipalInvestigatorName
					AND A.Year = ' + Convert(char(4), @FiscalYear) + ' AND A.Period = ''--''
			GROUP BY A.PrincipalInvestigatorName
		) / CAST(Count(CESLIST.AccountPIName) AS float) AS Expenses,
		CAST(SUM(CE.PctFTE) AS float) /
		(
			SELECT COUNT(A.PrincipalInvestigatorName)
			FROM FISDataMart.dbo.Accounts AS A
			WHERE ''L'' = A.Chart
					AND CESLIST.AccountPIName = A.PrincipalInvestigatorName
					AND A.Year = ' + Convert(char(4), @FiscalYear) + ' AND A.Period = ''--''
			GROUP BY A.PrincipalInvestigatorName
		) / CAST(Count(CESLIST.AccountPIName) AS float) 
			/ 100.0 AS FTE,
		Staff_Type.AD419_Line_Num as fte_sfn,
		''0'' AS isAssociated,
		''1'' AS isAssociable,
		''0'' AS isNonEmpExp
	FROM CESXProjects AS CE
		LEFT JOIN CESLIST on 
			CE.EID = CESLIST.EID
		LEFT JOIN FISDataMart.dbo.Accounts AS A ON
			''L'' = A.Chart
			AND CESLIST.AccountPIName = A.PrincipalInvestigatorName
			AND A.Year = ' + Convert(char(4), @FiscalYear) + ' AND A.Period = ''--''
		LEFT JOIN OrgXOrgR AS O ON
			A.Org = O.Org
			AND O.Chart = ''L''
			--AND O.Year = ' + Convert(char(4), @FiscalYear) + ' AND O.Period = ''--''
		LEFT JOIN Acct_SFN AS SFN ON 
			A.Account = SFN.Acct_ID
			AND SFN.Chart = ''L''
			AND A.Year = ' + Convert(char(4), @FiscalYear) + ' AND A.Period = ''--''
		LEFT JOIN PPSDataMart.dbo.Titles as Title ON 
			CESLIST.Title_Code = Title.TitleCode
		LEFT JOIN Staff_Type ON
			Title.StaffType = Staff_Type.Staff_Type_Code
WHERE	
	CE.CESSalaryExpenses <> 0
	AND CE.PctFTE <> 0
GROUP BY 
	--Chart,
	O.OrgR,
	A.Org , 
	--O.OrgR_Name,
	A.Account,
	--A.Account_Name,
	--CE.SubAccount,
	--SubAcct.SubAccount_Name ,
	left(SFN.SFN,3),
	CESLIST.AccountPIName,
	CE.EID,
	CESLIST.CESEmployeeFullName,
	CESLIST.Title_Code,
	left(Title.Name,35) ,
	Staff_Type.Staff_Type_Short_Name ,
	Staff_Type.AD419_Line_Num 
ORDER BY O.OrgR
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
--Update columns (semi-) specific to FIS source:

--Asscbl, NonEmpExp, ID, Name (Not dependent on other tables)
/*
PRINT 'Coding Associated, Asscbl, NonEmpExp (0,1,0)'
UPDATE    Expenses
SET              
	isAssociated = 0, 
	isAssociable = 1, 
	isNonEmpExp = 0
WHERE     (DataSource = 'CES')
*/
-------------------------------------------------------------------------
--Update columns dependent on other tables (denormalization)


----------------
--Update SubAccount, SubAccount Name for null subaccount:
-- Not needed since SubAcct is null for CE expenses
/*
PRINT 'Coding "default" subaccounts...'
UPDATE Expenses
SET 
	SubAcct = NULL
WHERE
	DataSource = 'CES'
	AND SubAcct = '-----'
*/
-------------------------------------------------------------------------
--Update Org_3 with Org_2 where former null, latter non-null:
	--(0 row(s) affected)
--PRINT 'Replacing ORG_3s with Org_2s where blank...'
/*
UPDATE Expenses
SET OrgR = Org
FROM
	Expenses as E 
		LEFT JOIN FIS.dbo.Organization as Org ON
			Org.Org = E.Org
			AND Org.Chart = 'L'
	WHERE
		E.DataSource = 'CES'
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

[12/17/2010] by kjt:
	Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
	
[12/20/2010] by kjt: 
	Changed PPS to PPSDataMart as applicable.

*/
