-- =============================================
-- Author:		Ken Taylor
-- Create date: August 2, 2016
-- Description:	Load the FIS_ExpensesFor204Projects table
-- This will take the portion of the PPS expenses that were not already 
--	included in the salary expenses and load them in the 204 FIS expenses table.
-- Prerequisites:
--	The UFY_FFY_FIS_Expenses table should already been loaded.
--	The AllAccountsFor204Projects table should already been loaded.
--	The Missing204AccountExpenses table should already been loaded.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadFISExpensesFor204Projects]
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--	20160810 by kjt: Added SubAccount and PrincipalInvestigator
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadFISExpensesFor204Projects] 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
TRUNCATE TABLE dbo.FIS_ExpensesFor204Projects

INSERT INTO dbo.FIS_ExpensesFor204Projects
SELECT DISTINCT t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OpFundNum, t1.ConsolidationCode,  t1.TransDocType, t1.OrgR, t1.Org, SUM(t1.Expenses) Expenses
--INTO [dbo].[FIS_ExpensesFor204Projects]
FROM [dbo].[All204NonExpiredExpensesV] t1 
WHERE (
	(t1.TransDocType IN (SELECT DocumentType FROM dbo.DocTypeCodesForLaborIncludedInFisExpenses))
	OR
	(t1.ConsolidationCode NOT IN (SELECT [Obj_Consolidatn_Num] FROM [dbo].ConsolCodesForLaborTransactions))
)

GROUP BY
     t1.[OPFundNum]
	 ,t1.ConsolidationCode
     ,t1.[Chart]
     ,t1.[Account]
	 ,t1.SubAccount
	 ,t1.PrincipalInvestigator
	 ,t1.TransDocType
	 ,t1.[OrgR]
	 ,T1.Org
	
HAVING SUM(Expenses) <> 0 
	
ORDER BY 
      t1.[OPFundNum]
     ,t1.[Chart]
     ,t1.[Account]
	 ,t1.SubAccount
	 ,t1.PrincipalInvestigator
	 ,t1.ConsolidationCode
	 ,t1.TransDocType
	 ,t1.[OrgR]
	 ,t1.Org
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
   
END