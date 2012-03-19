-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-02-03
-- Description:	Get the FISDataMart table record counts grouped by year as applicable.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetFISDataMartTableRecordCountsByYear] 
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @TableRecordCounts TABLE (TableName varchar(255), Year char(4), Count int) 

	INSERT INTO @TableRecordCounts 
	select  'Accounts', YEAR, COUNT(*)
	from Accounts
	group by Year order by year

	INSERT INTO @TableRecordCounts 
	select  'AccountType', null, COUNT(*)
	from AccountType

	INSERT INTO @TableRecordCounts 
	select  'ARC_Codes', null, COUNT(*)
	from ARC_Codes

	INSERT INTO @TableRecordCounts 
	select  'BalanceTypes', null, COUNT(*)
	from BalanceTypes

	INSERT INTO @TableRecordCounts 
	select  'BaseBudgetSubFundGroups', null, COUNT(*)
	from BaseBudgetSubFundGroups

	INSERT INTO @TableRecordCounts 
	select  'BillingIDConversions', null, COUNT(*)
	from BillingIDConversions

	INSERT INTO @TableRecordCounts 
	select  'DocumentOriginCodes', null, COUNT(*)
	from DocumentOriginCodes

	INSERT INTO @TableRecordCounts 
	select  'DocumentTypes', null, COUNT(*)
	from DocumentTypes

	INSERT INTO @TableRecordCounts 
	select  'FunctionCode', null, COUNT(*)
	from FunctionCode

	INSERT INTO @TableRecordCounts 
	select  'FundGroups', null, COUNT(*)
	from FundGroups

	INSERT INTO @TableRecordCounts 
	select  'GeneralLedgerProjectBalanceForAllPeriods', YEAR, COUNT(*)
	from GeneralLedgerProjectBalanceForAllPeriods
	group by Year order by year

	INSERT INTO @TableRecordCounts 
	select  'HigherEducationFunctionCodes', null, COUNT(*)
	from HigherEducationFunctionCodes

	INSERT INTO @TableRecordCounts 
	select  'Objects', YEAR, COUNT(*)
	from Objects
	group by Year order by year

	INSERT INTO @TableRecordCounts 
	select  'ObjectSubTypes', null, COUNT(*)
	from ObjectSubTypes

	INSERT INTO @TableRecordCounts 
	select  'ObjectTypes', null, COUNT(*)
	from ObjectTypes

	INSERT INTO @TableRecordCounts select  'OPFund', YEAR, COUNT(*)
	from OPFund
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'Organizations', YEAR, COUNT(*)
	from Organizations
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'PendingTrans', YEAR, COUNT(*)
	from PendingTrans
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'Projects', YEAR, COUNT(*)
	from Projects
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'SubAccounts', YEAR, COUNT(*) 
	from  SubAccounts
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'SubFundGroups', YEAR, COUNT(*)
	from SubFundGroups
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'SubObjects', YEAR, COUNT(*)
	from SubObjects
	group by Year order by year

	INSERT INTO @TableRecordCounts select  'Trans', YEAR, COUNT(*) 
	from Trans
	group by Year order by year


	INSERT INTO @TableRecordCounts select  'TransLog', FiscalYear, COUNT(*)
	from TransLog
	group by FiscalYear order by FiscalYear


	INSERT INTO @TableRecordCounts select  'TransactionLogV', FiscalYear, COUNT(*) 
	from TransactionLogV
	group by FiscalYear order by FiscalYear

	select * from @TableRecordCounts

END
