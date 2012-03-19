-- =============================================
-- Author:		Ken Taylor / Scott Kirkland
-- Create date: 01/05/2010 / 12/13/07
-- Description:	This script is run after the CESList and CESXProjects tables have been
-- populated by the accounting group, i.e. Steve Pesis and Co., or by populating
-- the dbo.CES_List_2009 table (as an example) from a spreadsheet provided by Steve and Co.
-- and then by running the sp_INSERT_CE_EXPENSES_INTO_CESXProjects, which inserts the records
-- into the table thus saving the accounting team from using the CE tab on the UI. 
-- Once the above tables have been populated then this script may be run.
-- Note that this script will not insert records for which it does not find an account
-- number; therefore, if the CESList.AccountPIName does not exactly match the 
-- Accounts.PrincipalInvestigatorName, it will not find an associated account number and
-- the record will NOT be inserted in the Expenses and Associations tables!  This is important!
-- Therefore if record(s) are missing, make sure the names match!.
--
-- This script does the following:
-- 1. Deletes all of the records from the associations table that
--    have an expenseID present in the expenses table with a datasource of 'CES'. 
-- 2. Deletes all of the records for the expenses table that have a datasource of 'CES'.
-- 3. Runs a query that joins the Accounts table to the CESList table where 
-- CESLIST.AccountPIName = Accounts.PrincipalInvestigatorName, plus
-- PPSDataMart titles for Title_Code_Name, OrgXOrgR for OrgR, Staff_Type for Staff_Type_Short_Name
-- Accounts for Account and Org, and the CESXProjects table for the Expense and PctFTE which is 
-- divided up N times based on the number of accounts returned where the PI name matches.
-- 4. Inserts the records into Expenses and then Associations with the corresponding Expenses.ExpenseID as
-- the Association's Expense's Foreign Key.
--
-- Modifications:
--
-- [12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
--
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_CE] 
	-- Add the parameters for the stored procedure here
(
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
BEGIN
--declare @IsDebug bit = 0 -- Uncomment these 2 lines if you want to paste the script and run it in a query window.
--declare @FiscalYear int = 2009

	DECLARE @TSQL varchar(MAX) = ''
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--Delete all FIS-sourced expense records:
--PRINT 'Deleting previous CES records...'

--DELETE CES Associations
Select @TSQL = 'DELETE FROM Associations WHERE ExpenseID in 
	(
		SELECT ExpenseID FROM Expenses WHERE DataSource = ''CES''
	);'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

--DELETE CES Expenses
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
PRINT '--Inserting new CES records...'

-- Author: Alan Lai
-- Date: 12/13/2007
-- Purpose:     Some sort of AD-419 query that takes the values out of some table (grabs CES expenses)
--                  and inserts them into the expenses table, then takes that expenseid value and 
--                  the accession number into the associations table.
--                  Not really sure what that means but that's what scott wanted.
--                  * Does not delete anything out of the expenses table, will let scott deal with that.

DECLARE @Accession char(7), @DataSource varchar(50), @OrgR char(4), @Chart char(1)
DECLARE @Account char(7), @SubAccount varchar(5), @PI_Name nvarchar(50)
DECLARE @Org varchar(50), @EID char(9), @EmployeeName nvarchar(50), @TitleCd varchar(4)
DECLARE @TitleCdName nvarchar(35), @ExpSFN char(3), @Expenses decimal(16, 2)
DECLARE @FTESFN char(3), @FTE decimal(16, 4), @isAssociated tinyint, @isAssociable tinyint
DECLARE @SubExpSFN varchar(4), @StaffGrpCd varchar(16)

DECLARE @ExpenseID int

DECLARE @isNonEmpExp int
SET @isNonEmpExp = 0

DECLARE @ECursor CURSOR

SET @ECursor = CURSOR FOR 
	SELECT 
        CE.Accession,
		'CES' AS DataSource, 
		'L' AS Chart,
		O.OrgR,
		A.Org as Org, 
		A.Account AS Account,
		NULL AS SubAcct,
		'220' AS exp_SFN, -- CES always State Appropriations
		CESLIST.AccountPIName AS PI_Name,
		CE.EID,
		'(CE PI) ' + CESLIST.AccountPIName AS Employee_Name,
		CESLIST.Title_Code AS TitleCd,
		left(Title.Name,35) AS Title_Code_Name,
		Staff_Type.Staff_Type_Short_Name AS staff_grp,
		SUM(CE.CESSalaryExpenses) / 
		(
			SELECT COUNT(A.PrincipalInvestigatorName)
			FROM FISDataMart.dbo.Accounts AS A
			WHERE 'L' = A.Chart
					AND CESLIST.AccountPIName = A.PrincipalInvestigatorName
					AND A.Year = @FiscalYear AND A.Period = '--'
			GROUP BY A.PrincipalInvestigatorName
		) / CAST(Count(CESLIST.AccountPIName) AS float) AS Expenses,
		CAST(SUM(CE.PctFTE) AS float) /
		(
			SELECT COUNT(A.PrincipalInvestigatorName)
			FROM FISDataMart.dbo.Accounts AS A
			WHERE 'L' = A.Chart
					AND CESLIST.AccountPIName = A.PrincipalInvestigatorName
					AND A.Year = @FiscalYear AND A.Period = '--'
			GROUP BY A.PrincipalInvestigatorName
		) / CAST(Count(CESLIST.AccountPIName) AS float) 
			/ 100.0 AS FTE,
		Staff_Type.AD419_Line_Num as fte_sfn,
		'1' AS isAssociated,
		'0' AS isAssociable,
		'0' AS isNonEmpExp
	FROM CESXProjects AS CE
		LEFT JOIN CESLIST on 
			CE.EID = CESLIST.EID
		LEFT JOIN FISDataMart.dbo.Accounts AS A ON
			'L' = A.Chart
			AND CESLIST.AccountPIName = A.PrincipalInvestigatorName
			AND A.Year = @FiscalYear AND A.Period = '--'
		LEFT JOIN OrgXOrgR AS O ON
			A.Org = O.Org
			AND O.Chart = 'L'
			AND A.Year = @FiscalYear AND A.Period = '--'
		LEFT JOIN Acct_SFN AS SFN ON 
			A.Account = SFN.Acct_ID
			AND SFN.Chart = 'L'
			AND A.Year = @FiscalYear AND A.Period = '--'
		LEFT JOIN PPSDataMart.dbo.Titles as Title ON 
			CESLIST.Title_Code = Title.TitleCode
		LEFT JOIN Staff_Type ON
			Title.StaffType = Staff_Type.Staff_Type_Code
WHERE	
	CE.CESSalaryExpenses <> 0
	AND CE.PctFTE <> 0
GROUP BY 
	O.OrgR,
	A.Org , 
	A.Account,
	left(SFN.SFN,3),
	CESLIST.AccountPIName,
	CE.EID,
	CESLIST.CESEmployeeFullName,
	CESLIST.Title_Code,
	left(Title.Name,35) ,
	Staff_Type.Staff_Type_Short_Name ,
	Staff_Type.AD419_Line_Num,
    CE.Accession
HAVING A.Account IS NOT NULL
ORDER BY PI_Name, O.OrgR

OPEN @ECursor

FETCH NEXT FROM @ECursor INTO @Accession, @DataSource, @Chart, @OrgR, @Org
    , @Account, @SubAccount, @ExpSFN, @PI_Name, @EID, @EmployeeName, @TitleCd
    , @TitleCdName, @StaffGrpCd, @Expenses, @FTE, @FTESFN, @isAssociated, @isAssociable, @isNonEmpExp

WHILE (@@FETCH_STATUS = 0)
BEGIN

	Select @TSQL = 'INSERT INTO AllExpenses (  DataSource
        , OrgR, Chart, Account
        , SubAcct, PI_Name, Org, EID
        , Employee_Name, TitleCd, Title_Code_Name 
        , Exp_SFN, Expenses, FTE_SFN, FTE
        , isAssociated, isAssociable, isNonEmpExp
        , Sub_Exp_SFN, Staff_Grp_Cd
    )
    VALUES ( ''' 
		+ @DataSource 
		+ ''', ''' 
		+ @OrgR +''', ''' 
		+ @Chart +''', ''' 
		+ @Account + ''', ' 
		+ ( CASE  WHEN @SubAccount IS NULL THEN  'NULL'
				  ELSE  '''' + Convert(varchar(5),@SubAccount) + '''' END ) 
		+', ''' + REPLACE(@PI_Name, '''', '''''') + ''', ' 
		+ ( CASE  WHEN @Org IS NULL THEN  'NULL'
				  ELSE '''' + @Org + '''' END )
		+ ', ''' + @EID+ ''', ''' 
		+ REPLACE(@EmployeeName, '''', '''''') 
		+ ''', ''' + @TitleCd
		+ ''', ''' + @TitleCdName
        + ''', ''' + @ExpSFN 
        + ''', ' + Convert(varchar(20), @Expenses) 
        + ', ''' + @FTESFN 
        + ''', ' + Convert(varchar(20), @FTE)
        + ', ' + Convert(varchar(5),@isAssociated) 
        + ', ' + Convert(varchar(5),@isAssociable) 
        + ', ' + Convert(varchar(5),@isNonEmpExp) 
        + ', NULL, ''' 
        + @StaffGrpCd 
        + ''');'
      
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			Print @TSQL
			EXEC(@TSQL) 
		END	
		
    -- Get back out the Expense ID from the expenses table
    -- Scope_Identity function pulls the last identity value generated within this context (script)
    SELECT @ExpenseID = @@Identity
    print @ExpenseID

    -- Insert the values into the associations table
    Select @TSQL = 'Insert into Associations (ExpenseID, OrgR, Accession, Expenses, FTE)
    values ('
     +  ( CASE  WHEN @ExpenseID IS NULL THEN  '@ExpenseID'
		        ELSE Convert(varchar(20),@ExpenseID)  END )
     + ', ' + ( CASE  WHEN @Org IS NULL THEN  'NULL'
				ELSE  '''' + @Org + '''' END ) 
     + ', ''' + @Accession  
     + ''', ' + Convert(varchar(20),@Expenses)  
     + ', '   + Convert(varchar(20), @FTE)
     + ')'
    
    IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			Print @TSQL
			EXEC(@TSQL)
		END	
		
    FETCH NEXT FROM @ECursor INTO @Accession, @DataSource, @Chart, @OrgR, @Org
    , @Account, @SubAccount, @ExpSFN, @PI_Name, @EID, @EmployeeName, @TitleCd
    , @TitleCdName, @StaffGrpCd, @Expenses, @FTE, @FTESFN, @isAssociated, @isAssociable, @isNonEmpExp
END

CLOSE @ECursor
DEALLOCATE @ECursor

END
