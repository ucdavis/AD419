﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: August 2, 2016
-- Description:	Loads the MissingExpensesFor204Projects table
-- This gets the accounts and expense sums for the missing 204 accounts and loads them into the
-- Missing204AccountExpenses table
-- Notes:
-- The AllAccountsFor204Projects must be loaded first.
-- This table must be loaded in order for the All204NonExpiredExpensesV to work properly.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadTheMissingExpensesFor204Projects]
		@FIscalYear = 2016,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications
--	20171002 by kjt: Added "SUB9" to the object exclusion list as per discussion with Shannon Tanguay 2017-10-02.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadTheMissingExpensesFor204Projects] 
	@FIscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	TRUNCATE TABLE Missing204AccountExpenses
	INSERT INTO Missing204AccountExpenses
	SELECT t1.Chart, t1.AccountNum Account, t3.AnnualReportCode, t3.OpFundNum, 
		ConsolidationCode, TransDocType, t4.OrgR, t3.Org, SUM(EXPEND) Expenses, t5.IsUCD 
	FROM
		FISDataMart.dbo.BalanceSummaryV t1
	INNER JOIN 
	(
		SELECT DISTINCT Chart, Account, AnnualReportCode
		FROM AllAccountsFor204Projects
		GROUP BY Chart, Account, AnnualReportCode

		EXCEPT 

		SELECT [chart]
			  ,[Account]
			  ,[annualReportCode]
		  FROM [AD419].[dbo].[UFY_FFY_FIS_Expenses]
  
		  group by chart, account, annualReportCode
	  ) t2 ON T1.CHART = t2.Chart AND t1.AccountNum = t2.Account AND t1.AnnualReportCode = t2.AnnualReportCode
	  INNER JOIN FisDataMart.dbo.Accounts t3 ON t2.Chart = t3.Chart AND t2.Account = t3.Account AND t2.AnnualReportCode = t3.AnnualReportCode AND t3.Year = 9999 and t3.Period = ''--''
	  INNER JOIN AllAccountsFor204Projects t5 ON t2.Chart = t5.Chart AND t2.Account = t5.Account AND t2.AnnualReportCode = t5.AnnualReportCode
	  LEFT OUTER JOIN OrgXOrgR t4 ON t3.Org = t4.Org and t3.Chart = t4.Chart
	  WHERE 
	  ((t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ' AND t1.FiscalPeriod BETWEEN ''04'' AND ''13'') OR 
			 (t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND t1.FiscalPeriod BETWEEN ''01'' AND ''03''))
			AND TransBalanceType IN (''AC'')
			AND ConsolidationCode NOT IN (''INC0'', ''BLSH'', ''SB74'', ''SUB9'')
			and t1.Chart+AccountNum NOT IN (
				SELECT DISTINCT Chart+Account 
				FROM dbo.udf_ArcCodeAccountExclusionsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ')
			)  
	  group by t1.Chart, T1.AccountNum, t3.AnnualReportCode, 
	   t3.OpFundNum, ConsolidationCode, TransDocType, t4.OrgR, t3.Org, t5.IsUCD having SUM(EXPEND) <> 0
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
		 
END