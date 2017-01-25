-- =============================================
-- Author:		Ken Taylor
-- Create date: August 2, 2016
-- Description:	Load the FISExpensesForNon204Projects
--
-- Notes: This will take the portion of the PPS expenses 
-- that were not already included in the salary expenses 
-- and load them in the NON 204 FIS expenses table.
--
-- Prerequisites:
-- The NewAccountSFN table must have been loaded first.
-- The [dbo].UFY_FFY_FIS_Expenses table must have been loaded.
--
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadFISExpensesForNon204Projects]
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
--	20160809 by kjt: Added SubAccount, PrincipalInvestigator, and SFN
-- =============================================
CREATE PROCEDURE usp_LoadFISExpensesForNon204Projects 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
TRUNCATE TABLE dbo.FIS_ExpensesForNon204Projects

INSERT INTO dbo.FIS_ExpensesForNon204Projects
SELECT DISTINCT t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OpFundNum, t1.ConsolidationCode,  t1.TransDocType, t1.OrgR, t1.Org, SUM(t1.Expenses) Expenses, SFN
--INTO AD419.dbo.FIS_ExpensesForNon204Projects
FROM [AD419].[dbo].FFY_Non204ExpensesV t1 --(view) 
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
	 ,t1.Org
	 ,t1.SFN
	
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
	 ,t1.SFN
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END