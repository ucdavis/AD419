-- =============================================
-- Author:		Ken Taylor
-- Create date: July 13, 2016
-- Description:	Return a list of excluded chart, account combinations for the fiscal year provided.
-- Usage:
/*
	USE AD419
	GO

	SELECT * FROM udf_ARCCodeAccountExclusionsForFiscalYear(FiscalYear)
*/
-- =============================================
CREATE FUNCTION [udf_ArcCodeAccountExclusionsForFiscalYear] 
(
	-- Add the parameters for the function here
	@FiscalYear int
)
RETURNS 
@ARCCodeAccountExclusions TABLE 
(
	Chart varchar(2),
	Account varchar(7),
    AnnualReportCode varchar(6),
    Comments varchar(MAX),
    Is204 bit,
    AwardNumber varchar(20),
    ProjectNumber varchar(24)
)
AS
BEGIN
	INSERT INTO @ARCCodeAccountExclusions
	SELECT
       [Chart]
      ,[Account]
      ,[AnnualReportCode]
      ,[Comments]
      ,[Is204]
      ,[AwardNumber]
      ,[ProjectNumber]
    FROM [AD419].[dbo].[ArcCodeAccountExclusions]
	
	RETURN 
END