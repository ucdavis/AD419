-- =============================================
-- Author:		Scott Kirkland
-- Create date: 12/13/07
-- Description:	Associates independents with AGARGAA
-- Modifications:
-- 2010/01/12 by Ken Taylor: Revised to use local FISDataMart tables.
-- 2010/01/19 by Ken Taylor: Changed the chart from "L" to "3" as 
-- these expenses are always chart 3!
--
-- [12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
--
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_IND] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 -- set this to 1 if you just want to print the SQL.
AS
BEGIN
	declare @TSQL varchar(max) = ''
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--Delete all FIS-sourced expense records:

--DELETE CES Associations
Select @TSQL = 'DELETE FROM Associations WHERE ExpenseID in 
	(
		SELECT ExpenseID FROM AllExpenses WHERE DataSource = ''IND''
	);
	'
If @IsDebug = 1
	Begin
		PRINT '-- Deleting previous CES records...'
		Print @TSQL
	End
ELSE
	Begin
		EXEC(@TSQL)
	End

--DELETE CES Expenses
	Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = ''IND'';
	'
If @IsDebug = 1
	Begin
		PRINT '-- Deleting previous CES records...'
		Print @TSQL
	End
ELSE
	Begin
		EXEC(@TSQL)
	End
-------------------------------------------------------------------------
PRINT '-- Inserting new IND records...'

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
		'IND' AS DataSource, 
		'3' AS Chart,
		CE.OrgR,
		CE.OrgR as Org, 
		'AGARGAA' AS Account,
		NULL AS SubAcct,
		'220' AS exp_SFN, -- IND always State Appropriations
		CESLIST.AccountPIName AS PI_Name,
		CE.EID,
		'(IND PI) ' + CESLIST.AccountPIName AS Employee_Name,
		CESLIST.Title_Code AS TitleCd,
		left(Title.Name,35) AS Title_Code_Name,
		Staff_Type.Staff_Type_Short_Name AS staff_grp,
		SUM(CE.CESSalaryExpenses) / CAST(Count(CESLIST.AccountPIName) AS float) AS Expenses,
		CAST(SUM(CE.PctFTE) AS float) / CAST(Count(CESLIST.AccountPIName) AS float) / 100.0 AS FTE,
		Staff_Type.AD419_Line_Num as fte_sfn,
		'1' AS isAssociated,
		'0' AS isAssociable,
		'0' AS isNonEmpExp
	FROM CESXProjects AS CE
		LEFT JOIN CESLIST on 
			CE.EID = CESLIST.EID
		LEFT JOIN PPSDataMart.dbo.Titles as Title ON 
			CESLIST.Title_Code = Title.TitleCode
		LEFT JOIN Staff_Type ON
			Title.StaffType = Staff_Type.Staff_Type_Code
WHERE	
	CE.CESSalaryExpenses <> 0
	AND CE.PctFTE <> 0
	AND CE.OrgR = 'AIND'
GROUP BY 
	CE.OrgR,
	CESLIST.AccountPIName,
	CE.EID,
	CESLIST.CESEmployeeFullName,
	CESLIST.Title_Code,
	left(Title.Name,35) ,
	Staff_Type.Staff_Type_Short_Name ,
	Staff_Type.AD419_Line_Num,
    CE.Accession
ORDER BY PI_Name, CE.OrgR

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
    -- SET @ExpenseID = scope_identity() -- No longer works with new approach; therefore, use the
    -- following instead:
    SET @ExpenseID = @@Identity

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
