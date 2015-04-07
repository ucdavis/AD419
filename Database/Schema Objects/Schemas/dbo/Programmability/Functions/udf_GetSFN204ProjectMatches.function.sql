-- =============================================
-- Author:		Ken Taylor
-- Create date: March 4, 2015
-- Description:	Returns a list of automated SFN 204 Account number to Project matches
-- Modifications:
--  2015-03-25 by kjt: Removed AD419 database specific references and added additional OR statement from 
--		204AcctXProj back to Projects via accession to handle manually entered projects without matching
--		award numbers. 
-- =============================================
CREATE FUNCTION [dbo].[udf_GetSFN204ProjectMatches] 
(
)
RETURNS 
@Sfn204ProjectMatches TABLE 
(
	Accession char(7)
  , Project varchar(24)
  , Chart varchar(2)
  , Account varchar(7)
  , OpFund varchar(6)
  , AwardNumbersDiffer bit
  , AccountAwardNum varchar(20), FundAwardNum varchar(20), FundName varchar(40)
  , PiNamesDiffer bit, AccountPI varchar(30), FundPI varchar(30)
  , AccountName varchar(40), AccountPurpose varchar(400), OPFundProjectTitle varchar(256), ProjectTitle varchar(200)
  , Expenses decimal(16,2)
)
AS
BEGIN
	
	INSERT INTO @Sfn204ProjectMatches
	SELECT DISTINCT Accession, Project
		, Chart, Account, OpFund
		, CASE WHEN AccountAwardNum NOT LIKE FundAwardNum THEN 1 ELSE 0 END AS AwardNumbersDiffer, AccountAwardNum, FundAwardNum, FundName
		, CASE WHEN AccountPI NOT LIKE FundPI THEN 1 ELSE 0 END AS PiNamesDiffer, AccountPI, FundPI
		, AccountName, AccountPurpose, OPFundProjectTitle, ProjectTitle
		, Expenses 
		FROM 
		(
		-- The inner query returns a list of 204 accounts with non-zero expenses, matched and non-matched.
		SELECT 
		 t1.[Chart]
		 ,[AccountID] Account
		,OpFundNum OpFund

		,t2.AwardNum AccountAwardNum
		,t3.AwardNum FundAwardNum


		,PrincipalInvestigatorName AccountPI
		,t3.PrimaryPIUserName FundPI

		,t2.AccountName
		,t3.FundName

		,t4.Title ProjectTitle
		,t2.Purpose AccountPurpose
		,t3.ProjectTitle OpFundProjectTitle

		 ,[Expenses]
 
		,t4.[Accession] -- Used to indicate that a match was not found.
			,t4.Project
	  FROM [dbo].[204AcctXProj] t1
	  left outer join FISDatamart.dbo.accounts t2 on account = accountid and t1.chart = t2.chart and year = 9999 and period = '--'
	  left outer join FISDatamart.dbo.OPFund t3 ON t2.OpFundNum = t3.FUndNum AND t2.Year = t3.Year and t2.Chart = t3.chart and t2.Period = t3.Period
	  left outer join [dbo].[AllProjects] t4 ON 
			t2.AwardNum = t4.CSREES_ContractNo OR -- First match by account award number
			t3.AwardNum = t4.CSREES_ContractNo OR -- then by OP Fund Award Number
			t4.CSREES_ContractNo LIKE '%' + t2.AwardNum OR -- then by a adding a missing "20" at the beginning of the award number. 
			t1.Accession = t4.Accession -- Lastly tru making a match if the accession number has already been manually entered in [204AcctXProj] table.
	  WHERE Expenses > 0
	  ) t1
	  ORDER BY Account, Accession

	RETURN 
END