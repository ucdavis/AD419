-- =============================================
-- Author:		Ken Taylor
-- Create date: August 2, 2016
-- Description:	Load the 204 PPS Expenses into the 204 PPS Expenses table.
-- Prerequsites:
--	The [AnotherLaborTransactions] must be loaded first.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadPPSExpensesFor204Projects]
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
--	20160810 by kjt: Added PrincipalInvestigator
--	20160820 vy kjt: Revised to use new table schema, plus update Org and OrgR.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadPPSExpensesFor204Projects] 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''


	SELECT @TSQL = '
	TRUNCATE TABLE [dbo].[PPS_ExpensesFor204Projects]
	INSERT INTO [dbo].[PPS_ExpensesFor204Projects] (
	   [Chart]
      ,[Account]
      ,[SubAccount]
      ,[PrincipalInvestigator]
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
      --,[OrgR]
      --,[Org]
      ,[EmployeeID]
      ,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[Amount]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
      ,[FTE]
	)
	SELECT 
	   t0.[Chart]
      ,t0.[Account]
      ,t0.[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
      ,[EmployeeID]
      ,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,SUM([Amount]) Amount
      ,[FringeBenefitSalaryCd]
      ,t0.[AnnualReportCode]
	  ,CONVERT(DECIMAL(18,4),CASE WHEN [FinanceDocTypeCd] IN (SELECT DocumentType FROM dbo.FinanceDocTypesForFTECalc)
	  AND 
			ObjConsol IN (select Obj_Consolidatn_Num FROM ConsolCodesForFTECalc) AND 
			[PayRate] <> 0 AND 
			DosCd IN (SELECT DOS_Code FROM dbo.DOSCodes)
		THEN 
			CASE 
				WHEN [RateTypeCd] = ''H'' THEN SUM(Amount) / ([PayRate] * 2088)
				ELSE SUM(Amount) / [PayRate] / 12 END
		ELSE 0
		END) AS FTE
  --INTO PPS_ExpensesFor204Projects
  FROM [dbo].[AnotherLaborTransactions] t0
  INNER JOIN (
	SELECT Chart, Account, SubAccount, PrincipalInvestigator, ConsolidationCode
	FROM [dbo].[All204NonExpiredExpensesV]
	GROUP BY Chart, Account, SubAccount, PrincipalInvestigator, ConsolidationCode
	) t1 ON t0.Chart = t1.Chart AND t0.Account = t1.Account AND t0.SubAccount = t1.SubAccount AND t0.ObjConsol = t1.ConsolidationCode
  INNER JOIN ConsolCodesForLaborTransactions t2 ON t0.ObjConsol = t2.Obj_Consolidatn_Num
  GROUP BY 
     t0.[Chart]
    ,t0.[Account]
    ,t0.[SubAccount]
	,PrincipalInvestigator
    ,[ObjConsol]
    ,[FinanceDocTypeCd]
    ,[DosCd]
    ,[EmployeeID]
    ,[EmployeeName]
    ,[TitleCd]
    ,[RateTypeCd]
    ,[Payrate]
    ,[FringeBenefitSalaryCd]
    ,t0.[AnnualReportCode]
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	SELECT @TSQL = '
  -- Update the Org and OrgR:
  UPDATE [dbo].PPS_ExpensesFor204Projects
  SET OrgR = t2.OrgR, Org = t2.Org
  FROM [dbo].PPS_ExpensesFor204Projects t1
  INNER JOIN [dbo].[All204NonExpiredExpensesV] t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account AND t1.SubAccount = t2.SubAccount
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	SELECT @TSQL = '
  update [dbo].PPS_ExpensesFor204Projects
  set EmployeeName = t2.FullName
  FROM [dbo].PPS_ExpensesFor204Projects t1
  INNER JOIN PPSDatamart.dbo.Persons t2 ON t1.EmployeeID = t2.EmployeeID 
  WHERE t1.employeeName IS NULL
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END