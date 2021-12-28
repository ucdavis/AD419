-- =============================================
-- Author:		Ken Taylor
-- Create date: March 6, 2014
-- Description:	Given a Fiscal year, return a list of Sub Fund Group Numbers
-- that have Account Assessment Type Codes
-- Usage:
/*
	SELECT * FROM [dbo].[udf_GetSubFundGroupNumsWithAccountAssessmentCodes](2014)
*/
-- =============================================
CREATE FUNCTION [dbo].[udf_GetSubFundGroupNumsWithAccountAssessmentCodes] 
(
	-- Add the parameters for the function here
	@FiscalYear varchar(4)
)
RETURNS 
@SubFundGroupNums TABLE 
(
	-- Add the column definitions for the TABLE variable here
	SubFundGroupNum varchar(10)
)
AS
BEGIN
	 INSERT INTO @SubFundGroupNums
	 select DISTINCT t3.SubFundGroupNum
	 from OPP_FIS..FINANCE.ORG_ACCOUNT_ASSESSMENT t1 
	 INNER JOIN Accounts t3 ON t1.ACCT_NUM = t3.Account AND t1.CHart_NUM = t3.Chart AND 
	 t1.FISCAL_YEAR = t3.Year 
	 WHERE t3.IsCAES = 1  AND  TypeCode NOT IN ('UB', 'PR', 'BS') AND ACTIVE_IND = 'Y' AND t1.FISCAL_YEAR >= @FiscalYear
	 ORDER BY SubFundGroupNum
	RETURN 
END