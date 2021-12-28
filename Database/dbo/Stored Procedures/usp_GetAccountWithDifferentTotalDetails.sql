-- =============================================
-- Author:		Ken Taylor
-- Create date: November 10,2019
-- Description:	Return the account details for an account 
--	with a different ARC code total Vs. Expense total.
-- Notes: This sp duplicates the hardcoded SQL in the AD419 DataContext:
--   DbRawSqlQuery<AccountWithDifferentTotalDetails> GetAccountWithDifferentTotalDetails(int fiscalYear, string chart, string account)
-- Usage:
/*

	USE [AD419]
	GO

	EXEC usp_GetAccountWithDifferentTotalDetails 
		@FiscalYear = 2019, 
		@Chart = '3', 
		@Account = 'ABSTAIR', 
		@IsDebug = 1

	GO

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE usp_GetAccountWithDifferentTotalDetails 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2019, 
	@Chart varchar(2) = '3',
	@Account varchar(7) = 'ABSTAIR',
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
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
		  FROM [dbo].[udf_GetAccountsWithDifferentTotals](' + CONVERT(varchar(4), @FiscalYear) + ') t1
		  left outer join FISDatamart.dbo.accounts t2 on t1.Account = t2.Account and t1.chart = t2.chart and year = 9999 --and period = ''--''
		  left outer join FISDatamart.dbo.OPFund t3 ON t2.OpFundNum = t3.FundNum AND t2.Year = t3.Year and t2.Chart = t3.chart and t2.Period = t3.Period
		  LEFT OUTER JOIN NewAccountSFN t6 ON t1.Chart = t6.Chart AND t1.Account = t6.Account
		  WHERE t1.Account = ''' + @Account + ''' AND t1.Chart = ''' + @Chart + '''
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END