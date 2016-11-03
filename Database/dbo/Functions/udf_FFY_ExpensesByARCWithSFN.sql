-- =============================================
-- Author:		Ken Taylor
-- Create date: August 16, 2016
-- Description:	Return a list of FFY expenses by ARC, Chart, and Account with SFN
-- Usage:
/*
	SELECT * FROM udf_FFY_ExpensesByARCWithSFN (2015)
*/
--
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_FFY_ExpensesByARCWithSFN 
(
	-- Add the parameters for the function here
	@FiscalYear int = 2015
)
RETURNS 
@Table_Var TABLE 
(
	   [AnnualReportCode] varchar(20)
      ,[Chart] varchar(2)
      ,[Account] varchar(7)
      ,[ConsolidationCode] varchar(4)
      ,[DirectTotal] money
      ,[IndirectTotal] money
      ,[Total] money
	  ,SFN varchar(5)
)
AS
BEGIN
	INSERT INTO @Table_Var
	SELECT
		t1.AnnualReportCode,
		t1.Chart,
		t1.Account,
		t1.ConsolidationCode,
		t1.DirectTotal,
		t1.IndirectTotal,
		t1.Total,
		t2.SFN 
	FROM
		dbo.FFY_ExpensesByARC AS t1 
			LEFT OUTER JOIN dbo.NewAccountSFN AS t2 
			ON t1.Chart = t2.Chart AND
			t1.Account = t2.Account 
	WHERE
		((t1.Chart + t1.Account) NOT IN (	SELECT
												Chart + Account AS Expr1 
											FROM
												dbo.udf_ARCCodeAccountExclusionsForFiscalyear(@fiscalYear)))
	
	RETURN 
END