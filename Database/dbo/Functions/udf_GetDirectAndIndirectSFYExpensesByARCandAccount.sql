-- =============================================
-- Author:		Ken Taylor
-- Create date: September 22, 2016
-- Description:	Return a list of Direct and Indirect SFY expenses via ARC code by Chart and Account.
--
-- NOTE: The DaFIS_AccountsByARC table must be loaded prior to running this procedure!
--
-- Usage: 
/*
	SELECT * FROM udf_GetDirectAndIndirectSFYExpensesByARCandAccount(2015) 
*/
-- Modifications:
--  20161115 by kjt: Added SFN as per Shannon.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetDirectAndIndirectSFYExpensesByARCandAccount] 
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
	SELECT * FROM udf_GetDirectAndIndirectExpensesByARCandAccount(@FiscalYear, 1)

	RETURN 
END