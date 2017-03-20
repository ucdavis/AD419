-- =============================================
-- Author:		Ken Taylor
-- Create date: August 10, 2016
-- Description:	Load the DaFIS_AccountsByARC table.
-- This table is used by several of the stored procedures
-- so I'm loading it once at the beginning of the process so
-- the data doesn't have to be fetched multiple times from campus
-- data warehouse.
-- Run this prior to running usp_Load_UFY_FFY_FIS_Expenses as it relies on the data
-- present in the table.
-- Usage:
/*
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_LoadDaFIS_AccountsByARC] @IsDebug = 1

	SELECT	'Return Value' = @return_value

	GO
*/
-- Modifications:
--	20160921 by kjt: Revised to use our ARC codes table because this way it can use the user-modified list.
--	20160928 by kjt: Added @FiscalYear to method signature so it can be called by Ad419DataHelper app.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadDaFIS_AccountsByARC]
(	@FiscalYear int = 2015, -- Not needed by provided for method signature consistency.
	@IsDebug bit = 0)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	DECLARE @ArcCodes varchar(MAX) = (SELECT [dbo].[udf_ArcCodesString](0))

	SELECT @TSQL = '
	TRUNCATE TABLE dbo.DaFIS_AccountsByARC

	INSERT INTO dbo.DaFIS_AccountsByARC (
	   [Chart]
      ,[Account]
      ,[AnnualReportCode]
      ,[OpFundNum]
	)
	SELECT  
	   [Chart]
      ,[Account]
      ,[AnnualReportCode]
      ,[OpFundNum] 
	FROM OPENQUERY(FIS_DS, ''
		SELECT Chart_Num "Chart", ACCT_NUM "Account", T1.ANNUAL_REPORT_CODE "AnnualReportCode", OP_FUND_NUM "OpFundNum" 
        FROM FINANCE.ORGANIZATION_ACCOUNT T1
		WHERE FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''''--''''  AND ANNUAL_REPORT_CODE IN (' + @ArcCodes + ')
        ORDER BY  Chart_Num, ACCT_NUM, T1.ANNUAL_REPORT_CODE, OP_FUND_NUM     
	'') AS t1
	ORDER BY 
	   [Chart]
      ,[Account]
      ,[AnnualReportCode]
      ,[OpFundNum] 
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
	
END