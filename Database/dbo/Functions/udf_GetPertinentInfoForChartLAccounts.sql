-- =============================================
-- Author:		Ken Taylor
-- Create date: June 21, 2016
-- Description:	This function returns a list of chart L accounts, their particulars, and the sum of expenses for each individual account.
-- Usage:		
/*
	SELECT * FROM AD419.dbo.udf_GetPertinentInfoForChartLAccounts(2015)
*/
-- Modifications:
--	20160816 by kjt: Revised to use new view FFY_ExpensesByARCWithSFN.  Note that NewAccountSFN table has to first be loaded
--		in order for the SFN to be populated.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetPertinentInfoForChartLAccounts] 
(	
	@FiscalYear int = 2015
)
RETURNS @ChartLAccountInfo TABLE (
	Chart varchar(2),
	Account varchar(7),
	AnnualReportCode varchar(6),
	AnnualReportCodeName varchar(40),
	SFN varchar(5),
	SFN_Description varchar(100),
	Total money,
	OrgR varchar(4),
	Org varchar(4),
	AccountName varchar(40),
	PrincipalInvestigatorName varchar(30),
	Purpose varchar(400),
	AwardEndDate datetime,
	UcAccountNum varchar(7),
	OpFundNum varchar(6),
	AccountAwardNum varchar(20),
	FundName varchar(40),
	ProjectTitle varchar(256),
	OpFundAwardEndDate varchar(30),
	OpFundAwardNum varchar(20)
)
AS
BEGIN

	INSERT INTO @ChartLAccountInfo
	SELECT 
		t1.Chart, 
		t1.Account, 
		t1.AnnualReportCode,
		t5.ARCName AnnualReportCodeName, 
		t1.SFN, 
		t6.[Description],
		SUM(Total) Total,
		t4.Org3, 
		t2.Org, 
		t2.AccountName AccountName, 
		t2.PrincipalInvestigatorName, 
		t2.Purpose, 
		t2.AwardEndDate,
		t2.A11AcctNum UcAccountNum, 
		t2.OpFundNum, 
		t2.AwardNum AccountAwardNum, 
		t3.FundName, 
		t3.ProjectTitle, 
		t3.AwardEndDate OpFundAwardEndDate,  
		t3.AwardNum OpFundAwardNum
	FROM udf_FFY_ExpensesByARCWithSFN (@FiscalYear) t1
	INNER  JOIN FISDataMart.dbo.Accounts t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.Year = 9999 AND t2.Period = '--'
	INNER  JOIN FISDataMart.dbo.OpFund t3 ON t2.Chart = t3.Chart AND t2.OpFundNum = t3.FundNum AND t3.Year = 9999 AND t3.Period = '--'
	INNER  JOIN FisDataMart.dbo.OrganizationsV t4 ON t2.Chart = t4.Chart AND t2.Org = t4.Org AND t4.Year = 9999 AND t4.Period = '--'
	INNER  JOIN FisDataMart.dbo.ARCCodes t5 ON t1.AnnualReportCode = t5.ARCCode
	LEFT OUTER JOIN dbo.AllSFN t6 ON t1.SFN = t6.SFN 
	WHERE t1.Chart = 'L' AND 
		t1.Chart+t1.Account NOT IN (SELECT Chart+Account FROM [dbo].[ArcCodeAccountExclusions] WHERE Year = @FiscalYear)
	GROUP BY t1.Chart, t1.Account, t1.AnnualReportCode, t1.SFN, 
		t4.Org3, t2.Org, t2.AccountName, t2.[PrincipalInvestigatorName], t2.Purpose, t2.[AwardEndDate],
		t2.A11AcctNum, t2.OpFundNum, t2.AwardNum, t3.FundName, t3.ProjectTitle, t3.AwardEndDate, t3.AwardNum, t5.ARCName,
		t6.[Description]

	RETURN
END