


-- =============================================
-- Author:		Ken Taylor
-- Create date: July 21, 2016
-- Description:	Get a list of OP Fund Numbers associated with 204 Projects
-- Usage:
/*
	USE AD419
	GO

	SELECT * FROM udf_Get204OpFundNumsForFiscalYear(2020)
	GO
*/
-- Notes:
-- The @FiscalYear paramater is not actually used, but retained to match function signatures
--		of other AD-419 functions for automated function calls.
-- Use the Op Funds with IsUCD = 0 to get the accounts whose 204 expenses we want to exclude because
-- they belong to projects outside of our AES. 
-- 
--	Modifications: 
--	2016-08-18 by kjt: Changed to use AllProjectsNew.
--	2021-04-06 by kjt: Revised to use FIS_DS' Organization_account table as ours
--		was missing one (1) OP Fund 35C42.
--	2021-04-22 by kjt: Revised to also return Chart as the same OpFund is used on
--		multiple charts, but having differing award numbers, causing incorrect 
--		matches on the majority of chart "L" accounts belonging to ANR and 
--		Vice Chancellor Orgs.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_Get204OpFundNumsForFiscalYear]
(
	 @FiscalYear int = 2020
)
RETURNS 
@OpFunds204 TABLE 
(
	Chart varchar(2),
	OpFundNum varchar(10), 
	IsUCD bit
)
AS
BEGIN
	--DECLARE @FiscalYear int = 2015
	--DECLARE @OpFunds204 TABLE (Chart varchar(2), OpFundNum varchar(10), IsUCD bit

	DECLARE @AccountOpFundNums TABLE (Chart varchar(2), OpFundNum varchar(6), AwardNum varchar(20))
	INSERT INTO @AccountOpFundNums
	SELECT * FROM OPENQUERY(FIS_DS, '
		SELECT DISTINCT 
		CHART_NUM "Chart", OP_FUND_NUM "OpFundNum", AWARD_NUM "AwardNum"
		FROM FINANCE.ORGANIZATION_ACCOUNT
		WHERE FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''--'' AND 
			CHART_NUM IN (''3'', ''L'') AND
			AWARD_NUM IS NOT NULL
	')

INSERT INTO @OpFunds204
SELECT DISTINCT COALESCE(F.Chart, A.Chart) Chart, COALESCE(F.FundNum, A.OpFundNum) OpFundNum, IsUCD
	 FROM udf_AllProjectsNewForFiscalYear(@FiscalYear) P
	 LEFT OUTER JOIN FISDataMart.dbo.OPFund F ON REPLACE(P.AwardNumber, '-', '') = REPLACE(F.AwardNum, '-','') AND F.Year = 9999 AND F.Period = '--'
     LEFT OUTER JOIN @AccountOpFundNums A ON REPLACE(P.AwardNumber, '-', '') = REPLACE(A.AwardNum, '-','') 
	 WHERE 
		Is204 = 1 AND
	    AwardNumber IS NOT NULL AND AwardNumber NOT LIKE '' AND
		COALESCE(F.FundNum, A.OpFundNum) IS NOT NULL
	 ORDER by Chart, OpFundNum
	
	RETURN 
END