-- =============================================
-- Author:		Ken Taylor / Scott Kirkland
-- Create date: 01/05/2010 / 12/13/07
-- Description:	This script is run after the CESList and CESXProjects tables have been
-- populated by the accounting group, i.e. Steve Pesis and Co., or by populating
-- the dbo.CesListImport table (as an example) from a spreadsheet provided by Steve and Co.
-- and then by running the sp_INSERT_CE_EXPENSES_INTO_CESXProjects, which inserts the records
-- into the table thus saving the accounting team from using the CE tab on the UI. 
-- Once the above tables have been populated then this script may be run.
--
-- This script does the following:
-- 1. Deletes all of the records from the associations table that
--    have an expenseID present in the expenses table with a datasource of 'CES'. 
-- 2. Deletes all of the records for the expenses table that have a datasource of 'CES'.
-- 3. Runs a query that joins the Accounts table to the CESList table, plus
-- PPSDataMart titles for Title_Code_Name, OrgXOrgR for OrgR, Staff_Type for Staff_Type_Short_Name, 
-- and the CESXProjects table for the Expense and PctFTE.
-- 4. Inserts the records into Expenses and then Associations with the corresponding Expenses.ExpenseID as
-- the Association's Expense's Foreign Key.
--
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[sp_Repopulate_AD419_CE]
		@FiscalYear = 9999,
		@SFN = N'220',  -- Note: setting this to null will use the SFN pulled from the NewAccountSFN table.
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
-- 2016-08-02 by kjt: Totally reworked to use the chart, account, and sub account 
-- now present in the import data, which is then imported into the CESXProjects table. 
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_CE] 
	-- Add the parameters for the stored procedure here
(
	@FiscalYear int = 9999,  -- This is because we're going to use the universal fiscal year.
	@SFN varchar(4) = '220', -- This will override the SFN present in the NewAccountSFN table.
	@IsDebug bit = 0
)
AS
BEGIN
--declare @IsDebug bit = 0 -- Uncomment these 2 lines if you want to paste the script and run it in a query window.
--declare @FiscalYear int = 9999
--declare @SFN varchar(4) = '220'
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Accession char(7), @DataSource varchar(50), @OrgR char(4), @Chart char(1)
	DECLARE @Account char(7), @SubAccount varchar(5), @PI_Name nvarchar(50)
	DECLARE @Org varchar(50), @EID char(9), @EmployeeName nvarchar(50), @TitleCd varchar(4)
	DECLARE @TitleCdName nvarchar(35), @ExpSFN char(3), @Expenses decimal(16, 2)
	DECLARE @FTESFN char(3), @FTE decimal(16, 4), @isAssociated tinyint, @isAssociable tinyint
	DECLARE @SubExpSFN varchar(4), @StaffGrpCd varchar(16)

	SET @DataSource = 'CES'
	SET @FiscalYear = 9999 -- Use the Universal Fiscal Year regardless of the one provided.

	DECLARE @ExpenseID int

	DECLARE @isNonEmpExp int
	SET @isNonEmpExp = 0

	DECLARE @TSQL varchar(MAX) = ''

--Delete all FIS-sourced expense records:
--PRINT 'Deleting previous CES records...'

--DELETE CES Associations
Select @TSQL = 'DELETE FROM Associations WHERE ExpenseID in 
	(
		SELECT ExpenseID FROM Expenses WHERE DataSource = '''+@DataSource+'''
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
Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = '''+@DataSource+'''
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
	DECLARE @ECursor CURSOR

	SET @ECursor = CURSOR FOR 
	SELECT 
			CE.Accession,
			@DataSource AS DataSource, 
			CE.Chart AS Chart,
			CE.OrgR,
			A.Org as Org, 
			CE.Account AS Account,
			ISNULL(CE.SubAccount, '-----') AS SubAcct,
			CASE WHEN @SFN IS NULL THEN SFN ELSE @SFN END AS exp_SFN, -- CES is always 220 State Appropriations
			CESLIST.AccountPIName AS PI_Name,
			CE.EID,
			'(CE PI) ' + CESLIST.AccountPIName AS Employee_Name,
			CESLIST.Title_Code AS TitleCd,
			left(Title.Name,35) AS Title_Code_Name,
			Staff_Type.Staff_Type_Short_Name AS staff_grp,
			SUM(CE.CESSalaryExpenses) 
			/ CAST(Count(CESLIST.AccountPIName) AS float) AS Expenses,
			CAST(SUM(CE.PctFTE) AS float) / CAST(Count(CESLIST.AccountPIName) AS float) 
				/ 100.0 AS FTE,
			Staff_Type.AD419_Line_Num as fte_sfn,
			'1' AS isAssociated,
			'0' AS isAssociable,
			'0' AS isNonEmpExp
		FROM CESXProjects AS CE
			LEFT JOIN CESLIST on 
				CE.EID = CESLIST.EID
			LEFT JOIN FISDataMart.dbo.Accounts AS A ON
				CE.Chart = A.Chart
				AND A.Year = @FiscalYear AND A.Period = '--'
				AND CE.Account = A.Account
			LEFT JOIN OrgXOrgR AS O ON
				A.Org = O.Org 
				AND A.Chart = O.Chart   
				AND A.Year = @FiscalYear AND A.Period = '--'
			--LEFT JOIN Acct_SFN AS SFN ON -- Use the NewAccountSFN table instead.
			--	A.Account = SFN.Acct_ID
			--	AND CE.Chart = SFN.Chart
			--	AND A.Year = @FiscalYear AND A.Period = '--'
			LEFT JOIN NewAccountSFN AS SFN ON
				A.Account = SFN.Account AND
				CE.Chart = SFN.Chart AND
				A.Year = @FiscalYear AND
				A.Period = '--'
			LEFT JOIN PPSDataMart.dbo.Titles as Title ON 
				CESLIST.Title_Code = Title.TitleCode
			LEFT JOIN Staff_Type ON
				Title.StaffType = Staff_Type.Staff_Type_Code
	WHERE	
		CE.CESSalaryExpenses <> 0
		AND CE.PctFTE <> 0
	GROUP BY 
		CE.OrgR,
		A.Org ,
		CE.Chart, 
		CE.Account,
		CE.SubAccount,
		left(SFN.SFN,3),
		CESLIST.AccountPIName,
		CE.EID,
		CESLIST.CESEmployeeFullName,
		CESLIST.Title_Code,
		left(Title.Name,35) ,
		Staff_Type.Staff_Type_Short_Name ,
		Staff_Type.AD419_Line_Num,
		CE.Accession,
		SFN.SFN
	HAVING CE.Account IS NOT NULL
	ORDER BY PI_Name, CE.OrgR


	OPEN @ECursor

	FETCH NEXT FROM @ECursor INTO @Accession, @DataSource, @Chart, @OrgR, @Org
		, @Account, @SubAccount, @ExpSFN, @PI_Name, @EID, @EmployeeName, @TitleCd
		, @TitleCdName, @StaffGrpCd, @Expenses, @FTE, @FTESFN, @isAssociated, @isAssociable, @isNonEmpExp

	WHILE (@@FETCH_STATUS <> -1)
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

		SELECT @ExpenseID = @@Identity;
		print '-- @ExpenseID: ' + ISNULL(CONVERT(varchar(30), @ExpenseID), 'Error - No ID returned!') + '
		';

		-- Insert the values into the associations table
		Select @TSQL = 'Insert into Associations (ExpenseID, OrgR, Accession, Expenses, FTE)
		values ('
		 +  ( CASE  WHEN @ExpenseID IS NULL THEN  '@ExpenseID'
					ELSE Convert(varchar(20),@ExpenseID)  END )
		 + ', ' + ( CASE  WHEN @OrgR IS NULL THEN  @Org
					ELSE  '''' + @OrgR + '''' END ) 
		 + ', ''' + @Accession  
		 + ''', ' + Convert(varchar(20),@Expenses)  
		 + ', '   + Convert(varchar(20), @FTE)
		 + ')
	---------------------------------------------------------
	'   
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
