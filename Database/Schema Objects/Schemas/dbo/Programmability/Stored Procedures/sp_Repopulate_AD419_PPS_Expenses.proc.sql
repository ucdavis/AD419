------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_PPS_Expenses
BY:	Ken Taylor
Created: August 11, 2016

DESCRIPTION: 

--USAGE:	
	EXECUTE sp_Repopulate_AD419_PPS_Expenses @FiscalYear = 2015, @IsDebug = 0, @TableName = 'AllExpensesNew'

DEPENDENCIES:
	PPS_ExpensesForNon204Projects must have been loaded first.

MODIFICATIONS: 
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_PPS_Expenses]
( 
	@FiscalYear int = 2015,
	@IsDebug bit = 0,
	@TableName varchar(100) = 'AllExpenses'
)
AS
declare @TSQL varchar(MAX) = null;

BEGIN
-- First check if their are any expense without OrgRs:
	BEGIN
		DECLARE @NumBlankOrgs int = 0
		SELECT @NumBlankOrgs = (SELECT COUNT(*) 
		FROM FIS_ExpensesForNon204Projects
		WHERE OrgR IS NULL)
		IF @NumBlankOrgs > 0
		BEGIN 
			PRINT '-- Not all PPS Expenses have OrgR assigned.  Assign departments beore proceeding!'
			RETURN 
		END
	END
-------------------------------------------------------------------------
BEGIN TRANSACTION
-------------------------------------------------------------------------
--Delete all PPS-sourced expense records:
Select @TSQL = 'DELETE FROM ' + @TableName + ' WHERE DataSource = ''PPS'''
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end

-------------------------------------------------------------------------
--Insert PPS expenses from PPS_ExpensesForNon204Projects.
Select @TSQL = 'INSERT INTO ' + @TableName + '
	(
	   [DataSource]
      ,[OrgR]
      ,[Chart]
      ,[Account]
      ,[SubAcct]
      ,[PI_Name]
      ,[Org]
      ,[EID]
      ,[Employee_Name]
      ,[TitleCd]
      ,[Title_Code_Name]
      ,[Exp_SFN]
      ,[Expenses]
      ,[FTE_SFN]
      ,[FTE]
      ,[isAssociated]
      ,[isAssociable]
      ,[isNonEmpExp]
      ,[Sub_Exp_SFN]
      ,[Staff_Grp_Cd]
	)
	(
	SELECT 
	''PPS'' AS DataSource,
	   [OrgR]
      ,[Chart]
      ,[Account]
      ,SubAccount [SubAcct]
      ,PrincipalInvestigator [PI_Name]
      ,[Org]
      ,EmployeeId [EID]
      ,EmployeeName [Employee_Name]
      ,[TitleCd]
      ,t2.AbbreviatedName [Title_Code_Name]
      ,left(SFN,3) [Exp_SFN]
      ,SUM(Amount) Expenses
      ,[AD419_Line_Num] [FTE_SFN]
      ,SUM([FTE]) FTE
      ,0 [isAssociated]
      ,1 [isAssociable]
      ,0 [isNonEmpExp]
      ,NULL [Sub_Exp_SFN]
      ,[Staff_Type_Short_Name] [Staff_Grp_Cd]
	FROM PPS_ExpensesForNon204Projects t1
	LEFT OUTER JOIN PPSDatamart.dbo.Titles t2 ON t1.TitleCd = t2.TitleCode
	LEFT OUTER JOIN [dbo].[staff_type] t3 ON t2.StaffType = t3.Staff_Type_Code
	WHERE SFN NOT BETWEEN ''201'' AND ''205'' 
	GROUP BY [OrgR]
      ,[Chart]
      ,[Account]
	  ,SubAccount
	  ,PrincipalInvestigator 
	   ,[Org]
	   ,EmployeeId
	   ,EmployeeName 
	   ,[TitleCd]
	   ,t2.AbbreviatedName
	   ,left(SFN,3)
	   ,[AD419_Line_Num]
	   ,[Staff_Type_Short_Name] 
	 HAVING SUM(Amount) <> 0
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
Select @TSQL = '
-- We should have taken case of this beforehand.
--DELETE FROM ' + @TableName + '
--WHERE     (OrgR IS NULL) AND DataSource = ''PPS''

UPDATE    ' + @TableName + '
SET              SubAcct = NULL
WHERE     (SubAcct = ''-----'') AND DataSource = ''PPS''

UPDATE    ' + @TableName + '
SET              FTE = 0
WHERE     (FTE IS NULL) AND DataSource = ''PPS''

UPDATE    ' + @TableName + '
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
