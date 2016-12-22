-- =============================================
-- Author:		Ken Taylor
-- Create date: June 8, 2016
-- Description:	Return a list of Direct and Indirect FFY expenses via ARC code by Chart and Account.
--
-- NOTE: The DaFIS_AccountsByARC table must be loaded prior to running this procedure!
--
-- Usage: 
/*
	SELECT * FROM udf_GetDirectAndIndirectFFYExpensesByARCandAccount(2015) 

-- This function is also used to populate the FFY_Expenses_ByARC table:
	TRUNCATE TABLE FFY_ExpensesByARC
	INSERT INTO FFY_ExpensesByARC
	SELECT * FROM dbo.udf_GetDirectAndIndirectFFYExpensesByARCandAccount(2015)
*/
-- Modifications:
--  20160922 by kjt: Revised to use udf_GetDirectAndIndirectExpensesByARCandAccount
--  20161115 by kjt: Added SFN as per Shannon.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetDirectAndIndirectFFYExpensesByARCandAccount] 
(
	@FiscalYear int
)
RETURNS 
@DirectAndIndirectExpenses TABLE 
(
	AnnualReportCode varchar(20), 
	Chart varchar(2),
	Account varchar(7),
	ConsolidationCode varchar(4),
	DirectTotal money,
	IndirectTotal money,
	Total money,
	SFN varchar(5),
	OpFundNum varchar(6)
)
AS
BEGIN
	
	INSERT INTO @DirectAndIndirectExpenses
	SELECT * FROM udf_GetDirectAndIndirectExpensesByARCandAccount(@FiscalYear, 0)

	RETURN 
END