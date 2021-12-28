



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
--	20201125 by kjt: Revised to filter out GLJV Labor Related expenses
--		as it was necessary to add them back to the UFY_FFY_FIS_Expenses table
--		as their consolidation codes are used as part of an inner join when
--		loading the PPS(Labor) expenses.
--	20201126 by kjt: Refined where clause so that transactions for 
--		all doc types would be loaded except those on GLJV within the
--		Labor Transactions range.  The previous doc types has been removed
--		because UC Path no longer includes them, so filtering them out no 
--		longer has any purpose except for GLJV within the labor obj consol
--		range.
--	20201126 by kjt: Revised logic remove other non-GLJV doc types if the sum
--		them and the GLJV doc type = zero (0), meaning a credit when the net
--		results in zero dollars.  This is because we were having issues where 
--		the amounts on JV or GEC doc types were resulting in a credit when it 
--		should have been an overall zero on an account on a given consolidation code.
--	20211113 by kjt: Revised logic to include SUB6 expenses with Object name like REBATE
--		in order to include various Graduate Student rebate expenses which will never
--		be present in SUB6 labor expenses.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadFISExpensesForNon204Projects] 
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
SELECT DISTINCT t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OpFundNum, t1.ConsolidationCode,  t1.ObjectCode, t1.TransDocType, t1.OrgR, t1.Org, SUM(t1.Expenses) Expenses, SFN
--INTO AD419.dbo.FIS_ExpensesForNon204Projects
FROM [AD419].[dbo].FFY_Non204ExpensesV t1 --(view) 
INNER JOIN (
		SELECT Chart, Account, ConsolidationCode--, SUM(Expenses) UFY_Expenses 
		FROM UFY_FFY_FIS_Expenses
		GROUP BY Chart, Account, ConsolidationCode
		HAVING SUM(Expenses) <> 0
		) t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t1.ConsolidationCode = t2.ConsolidationCode
WHERE (
	(t1.ConsolidationCode NOT IN (SELECT Obj_Consolidatn_Num FROM ConsolCodesForLaborTransactions)) OR
	(t1.TransDocType != ''GLJV'') OR

	-- 20211113 by kjt: Added GRAD various grad student SUB6 rebates. 
	(t1.ConsolidationCode = ''SUB6'' AND 
		t1.ObjectCode IN (
			SELECT DISTINCT Object 
			FROM FISDataMart.dbo.Objects
			WHERE Year = ''9999'' AND Chart = ''3'' AND 
				ConsolidatnCode = ''SUB6'' AND
				Name LIKE''%REBATE%''
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
	 ,t1.ObjectCode
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