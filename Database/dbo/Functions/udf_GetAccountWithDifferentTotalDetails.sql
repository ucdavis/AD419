-- =============================================
-- Author:		Ken Taylor
-- Create date: November 10, 2019
-- Description:	Duplicates the logic previously contained in the hardcoded SQL in the AD419 DataContext:
--   DbRawSqlQuery<AccountWithDifferentTotalDetails> GetAccountWithDifferentTotalDetails(int fiscalYear, string chart, string account) 
-- Usage:
/*
	USE [AD419]
	GO

	SELECT * FROM udf_GetAccountWithDifferentTotalDetails(2019, '3', 'ABSTAIR')
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_GetAccountWithDifferentTotalDetails 
(
	@FiscalYear int = 2019,
	@Chart varchar(2) = '3', 
	@Account varchar(7) = 'ABSTAIR'
)
RETURNS 

@AccountsWithDifferentTotalDetails TABLE 
(
	 Chart varchar(2)
	,Account varchar(7)
	,OpFund varchar(6)
	,AccountAwardNum varchar(20)
	,FundAwardNum varchar(20)
	,AccountPi varchar(50)
	,FundPi varchar(50)
	,AccountName varchar(40)
	,FundName varchar(40)
	,AccountPurpose varchar(400)
	,OpFundProjectTitle varchar(256)
	,fyExpensesByArcTotal money
	,Ad419ExpensesTotal  money
	,AwardEndDate datetime2(7)
	,Sfn varchar(10)
	,ExpirationDate datetime2(7)
	,Org varchar(4)
	,AnnualReportCode varchar(6)
)
AS
BEGIN
	INSERT INTO @AccountsWithDifferentTotalDetails
	SELECT 
			 t1.[Chart]
			,t1.[Account]
			,t2.OpFundNum OpFund
			,t2.AwardNum AccountAwardNum
			,t3.AwardNum FundAwardNum
			,PrincipalInvestigatorName AccountPi
			,t3.PrimaryPIUserName FundPi
			,t2.AccountName
			,t3.FundName
			,t2.Purpose AccountPurpose
			,t3.ProjectTitle OpFundProjectTitle
			,t1.FFY_ExpensesByARC_Total AS FfyExpensesByArcTotal
			,t1.ExpensesTotal Ad419ExpensesTotal 
			,t2.AwardEndDate
			,t6.Sfn
			,t6.ExpirationDate
			,t2.Org
			,t2.AnnualReportCode
		  FROM [dbo].[udf_GetAccountsWithDifferentTotals](@FiscalYear) t1
		  left outer join FISDatamart.dbo.accounts t2 on t1.Account = t2.Account and t1.chart = t2.chart and year = 9999 --and period = ''--''
		  left outer join FISDatamart.dbo.OPFund t3 ON t2.OpFundNum = t3.FundNum AND t2.Year = t3.Year and t2.Chart = t3.chart and t2.Period = t3.Period
		  LEFT OUTER JOIN NewAccountSFN t6 ON t1.Chart = t6.Chart AND t1.Account = t6.Account
		  WHERE t1.Account = @Account AND t1.Chart = @Chart

	RETURN 
END