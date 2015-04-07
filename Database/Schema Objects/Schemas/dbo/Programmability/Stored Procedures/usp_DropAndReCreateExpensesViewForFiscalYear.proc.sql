-- =============================================
-- Author:		Ken Taylor
-- Create date: December 22, 2014
-- Description:	Drop and re-create the Expenses view with the 
-- correct year for the ARC Code Exclusions table.
-- Note: With the incorporation of the ARC Code Exclusions table, it is necessary to drop
-- and recreate the Expenses view every reporting period.
-- This procedure also handles the remapping of various reports orgs, i.e., CABA, BCPB, 
-- as opposed to actually changing their OrgR in the AllExpenses table. 
-- Usage:
/*
DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_DropAndReCreateExpensesViewForFiscalYear]
		@FiscalYear = N'2014',
		@IsDebug = 0

SELECT	'Return Value' = @return_value
GO
*/
-- =============================================
CREATE PROCEDURE usp_DropAndReCreateExpensesViewForFiscalYear 
	@FiscalYear varchar(4) = '2014', --Fiscal Year for the AD-419 reporting period.
	@IsDebug bit = 0 -- Set to 1 to print generated SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @FiscalYear varchar(4) = '2014'
	--DECLARE @IsDebug bit = 1
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
DROP VIEW [dbo].[Expenses]
'

	SELECT @TSQL += '
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON
'

	SELECT @TSQL += '
CREATE VIEW [dbo].[Expenses]
AS
SELECT        ExpenseID, 
			  DataSource, 
			  (CASE [OrgR] 
					WHEN ''AEVE'' THEN ''BEVE'' 
					WHEN ''BCPB'' THEN ''BEVE'' 
					WHEN ''AMCB'' THEN ''BMCB''
					WHEN ''BGEN'' THEN ''BMCB''
					WHEN ''AMIC'' THEN ''BMIC'' 
					WHEN ''ANPB'' THEN ''BNPB'' 
					WHEN ''APLB'' THEN ''BPLB''
					WHEN ''CABA'' THEN ''ADNO''
					WHEN ''ACTR'' THEN ''ADNO'' 
					ELSE OrgR END) AS OrgR, 
			  Chart, 
			  Account, 
			  SubAcct, 
			  PI_Name, 
			  Org, 
			  EID, 
			  Employee_Name, 
			  TitleCd, 
			  Title_Code_Name, 
			  Exp_SFN, 
			  Expenses, 
			  FTE_SFN, 
              FTE, 
			  isAssociated, 
			  isAssociable, 
			  isNonEmpExp, 
			  Sub_Exp_SFN, 
			  Staff_Grp_Cd
FROM	dbo.AllExpenses
WHERE	(Account NOT IN
            (SELECT Account
             FROM   dbo.ArcCodeAccountExclusions
             WHERE  (Year = ' + @FiscalYear + ') AND (Chart = ''3''))
			 ) OR 
			 (Account IS NULL)         
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END