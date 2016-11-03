-- =============================================
-- Author:		Ken Taylor
-- Create date: March 4th, 2015
-- Description:	Return a list of all SFN 204 Account expenses with their affiliated project matches.
-- Usage:
/*
	EXEC [dbo].[usp_GetSFN204ProjectMatches]
*/
-- Prerequisites:
-- AllAccountsFor204Projects and FFY_SFN_Entries must have been loaded.
--
-- Modifications:
--	2015-03-17 by kjt: Revised to use new OP Fund columns instead of pulling missing columns from campus.
--  2015-03-25 by kjt: Removed AD419 database specific references and added additional OR statement from 
--		204AcctXProj back to Projects via accession to handle manually entered projects without matching
--		award numbers. 
--	2016-09-27 by kjt: Revised to use new database schema.  
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetSFN204ProjectMatches] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @SFN_204_OP_Funds TABLE (OP_FUND_NUM varchar(6), PRIMARY_PI_USER_NAME varchar(30), PROJECT_TITLE varchar(256))
	--INSERT INTO @SFN_204_OP_Funds 
	--SELECT * FROM OPENQUERY(FIS_DS, 'SELECT OP_FUND_NUM, PRIMARY_PI_USER_NAME, PROJECT_TITLE
	--FROM FINANCE.OP_FUND 
	--WHERE FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''--''
	--ORDER BY OP_FUND_NUM')

	DECLARE @FiscalYear int = (SELECT FiscalYear FROM [dbo].[CurrentFiscalYear])

	SELECT DISTINCT 
		Accession, Project
		, Chart, Account, OpFund
		, CASE WHEN AccountAwardNum NOT LIKE FundAwardNum THEN 1 ELSE 0 END AS AwardNumbersDiffer, AccountAwardNum, FundAwardNum, FundName
		, CASE WHEN AccountPI NOT LIKE FundPI THEN 1 ELSE 0 END AS PiNamesDiffer, AccountPI, FundPI
		, AccountName, AccountPurpose, OPFundProjectTitle, ProjectTitle
		, ProjectEndDate
		, IsExpired
		, Expenses 

	FROM 
	(
	-- The inner query returns a list of 204 accounts with non-zero expenses, matched and non-matched.
		SELECT 
			 t1.[Chart]
			 ,[AccountID] Account
			,t2.OpFundNum OpFund

			,t2.AwardNum AccountAwardNum
			,t3.AwardNum FundAwardNum

			,PrincipalInvestigatorName AccountPI
			,t3.PrimaryPIUserName FundPI

			,t2.AccountName
			,t3.FundName

			,ISNULL(t4.Title, '') ProjectTitle
			,t2.Purpose AccountPurpose
			,t3.ProjectTitle OpFundProjectTitle

			 ,[Expenses]
			 ,t4.ProjectEndDate
			 ,IsCurrentProject ^1 AS IsExpired
 
			,ISNULL(t4.[AccessionNumber], '') Accession-- Used to indicate that a match was not found.
			,ISNULL(t4.ProjectNumber, '') Project
		  FROM [dbo].[204AcctXProjV] t1
		  left outer join FISDatamart.dbo.accounts t2 on account = accountid and t1.chart = t2.chart and year = 9999 and period = '--'
		  left outer join FISDatamart.dbo.OPFund t3 ON t2.OpFundNum = t3.FUndNum AND t2.Year = t3.Year and t2.Chart = t3.chart and t2.Period = t3.Period
		  left outer join udf_AllProjectsNewForFiscalYear(@FiscalYear) t4 ON 
				t1.Accession = t4.AccessionNumber -- Lastly tru making a match if the accession number has already been manually entered in [204AcctXProj] table.
		  WHERE Expenses > 0
	  ) t1
	  ORDER BY Account, Accession
END