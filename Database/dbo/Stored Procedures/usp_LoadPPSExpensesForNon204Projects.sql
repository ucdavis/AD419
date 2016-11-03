-- =============================================
-- Author:		Ken Taylor
-- Create date: August 2, 2016
-- Description:	Load the PPSExpensesForNon204Projects table
-- Notes:
-- The [dbo].NewAccountSFN, [dbo].UFY_FFY_FIS_Expenses and
-- [AnotherLaborTransactions] must be loaded first.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadPPSExpensesForNon204Projects]
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
-- 20160809 by kjt: Added PrincipalInvestigator
-- =============================================
CREATE PROCEDURE usp_LoadPPSExpensesForNon204Projects 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
TRUNCATE TABLE [dbo].PPS_ExpensesForNon204Projects
INSERT INTO [dbo].PPS_ExpensesForNon204Projects
SELECT t0.[Chart]
      ,t0.[Account]
      ,[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
	  ,OrgR
	  ,Org
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
		END) AS FTE,
		SFN
--INTO PPS_ExpensesForNon204Projects
  FROM [dbo].[AnotherLaborTransactions] t0
  INNER JOIN (
	SELECT Chart, Account, ConsolidationCode, PrincipalInvestigator, SFN, OrgR
	FROM [dbo].FFY_Non204ExpensesV
	GROUP BY Chart, Account, ConsolidationCode, PrincipalInvestigator, SFN, OrgR
	) t1 ON t0.Chart = t1.Chart AND t0.Account = t1.Account AND t0.ObjConsol = t1.ConsolidationCode
  INNER JOIN ConsolCodesForLaborTransactions t2 ON t0.ObjConsol = t2.Obj_Consolidatn_Num
  GROUP BY 
	   t0.[Chart]
      ,t0.[Account]
      ,[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
	  ,OrgR
	  ,Org
      ,[EmployeeID]
      ,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[FringeBenefitSalaryCd]
      ,t0.[AnnualReportCode]
	  ,SFN
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)   

	SELECT @TSQL = '
  update [dbo].PPS_ExpensesForNon204Projects
  set EmployeeName = t2.FullName
  FROM [dbo].PPS_ExpensesForNon204Projects t1
  INNER JOIN PPSDatamart.dbo.Persons t2 ON t1.EmployeeID = t2.EmployeeID 
  WHERE t1.employeeName IS NULL
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)  
END