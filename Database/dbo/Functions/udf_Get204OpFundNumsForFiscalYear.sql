-- =============================================
-- Author:		Ken Taylor
-- Create date: July 21, 2016
-- Description:	Get a list of OP Fund Numbers associated with 204 Projects
-- Usage:
/*
	USE AD419
	GO

	SELECT * FROM udf_Get204OpFundNumsForFiscalYear(2015)
	GO
*/
-- Notes:
-- Use the Op Funds with IsUCD = 0 to get the accounts whose 204 expenses we want to exclude because
-- they belong to projects outside of our AES. 
-- 
--	Modifications: 
--	2016-08-18 by kjt: Changed to use AllProjectsNew.
-- =============================================
CREATE FUNCTION [dbo].[udf_Get204OpFundNumsForFiscalYear]
(
	 @FiscalYear int = 2015
)
RETURNS 
@OpFunds204 TABLE 
(
	OpFundNum varchar(10), 
	IsUCD bit
)
AS
BEGIN
	--DECLARE @FiscalYear int = 2015
	--DECLARE @OpFunds204 TABLE (OpFundNum varchar(10), IsUCD bit

INSERT INTO @OpFunds204
SELECT DISTINCT COALESCE(F.FundNum, A.OpFundNum) OpFundNum, IsUCD
	 FROM udf_AllProjectsNewForFiscalYear(@FiscalYear) P
	 LEFT OUTER JOIN FISDataMart.dbo.OPFund F ON REPLACE(P.AwardNumber, '-', '') = REPLACE(F.AwardNum, '-','') AND F.Year = 9999 AND F.Period = '--'
     LEFT OUTER JOIN FISDataMart.dbo.Accounts A ON REPLACE(P.AwardNumber, '-', '') = REPLACE(A.AwardNum, '-','') AND A.Year = 9999 AND A.Period = '--'
	 WHERE 
		Is204 = 1 AND
	    AwardNumber IS NOT NULL AND AwardNumber NOT LIKE '' AND
		COALESCE(F.FundNum, A.OpFundNum) IS NOT NULL
	 ORDER by 1
	
	RETURN 
END