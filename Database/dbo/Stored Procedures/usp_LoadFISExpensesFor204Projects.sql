




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
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--	20160810 by kjt: Added SubAccount and PrincipalInvestigator
--	20201125 by kjt: Revised to filter out GLJV Labor Related expenses
--		as it was necessary to add them back to the UFY_FFY_FIS_Expenses table
--		as their consolidation codes are used as part of an inner join when
--		loading the PPS(Labor) expenses.
--	20201126 by kjt: Revised where clause filtering to allow all transactions
--		to be included EXCEPT those on GLJV within the Labor Transactions
--		consolidation codes.  The Doc Type filtering was also removed because
--		UCP does not include them.
--	20201126 by kjt: Revised logic remove other non-GLJV doc types if the sum
--		them and the GLJV doc type = zero (0), meaning a credit when the net
--		results in zero dollars.  This is because we were having issues where 
--		the amounts on JV or GEC doc types were resulting in a credit when it 
--		should have been an overall zero on an account on a given consolidation code.
--	20211113 by kjt: Added ObjectCode field to list of columns for later filtering.
--
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
SELECT DISTINCT t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OpFundNum, t1.ConsolidationCode, t1.ObjectCode, t1.TransDocType, t1.OrgR, t1.Org, SUM(t1.Expenses) Expenses
--INTO [dbo].[FIS_ExpensesFor204Projects]
FROM [dbo].[All204NonExpiredExpensesV] t1 
INNER JOIN (
	-- This inner join removes any non GLJV doc types for a given consolidation code where
	-- it is zeroing out transactions on a GLJV doc type for a given consolidation code. 
	SELECT Chart, Account, ConsolidationCode
	FROM All204NonExpiredExpensesV
	GROUP BY Chart, Account, ConsolidationCode
	HAVING SUM(Expenses) <> 0
) t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t1.ConsolidationCode = t2.ConsolidationCode

WHERE (
	(t1.ConsolidationCode NOT IN (SELECT Obj_Consolidatn_Num FROM ConsolCodesForLaborTransactions)) 
	-- Allow any non-labor consolidation code regardless of the doc type
	OR
	(t1.TransDocType != ''GLJV'') -- Allow any remaining, i.e., labor, consolidation codes where the doc type is not GLJV.
	OR
	(t1.ConsolidationCode = ''SUB6'' AND 
		t1.ObjectCode IN (
			SELECT DISTINCT Object
			FROM FISDataMart.dbo.Objects
			WHERE Year = 9999 AND Chart = ''3'' AND
			Name LIKE ''%REBATE%''
		)
	)
)

GROUP BY
     t1.[OPFundNum]
	 ,t1.ConsolidationCode
	 ,t1.ObjectCode
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
	 ,T1.ObjectCode
	 ,t1.TransDocType
	 ,t1.[OrgR]
	 ,t1.Org
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
   
END