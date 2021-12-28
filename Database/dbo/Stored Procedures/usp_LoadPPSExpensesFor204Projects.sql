


-- =============================================
-- Author:		Ken Taylor
-- Create date: August 2, 2016
-- Description:	Load the 204 PPS Expenses into the 204 PPS Expenses table.
-- Prerequisites:
--	The [AnotherLaborTransactions] must be loaded first.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadPPSExpensesFor204Projects]
		@FiscalYear = 2020,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
--	20160810 by kjt: Added PrincipalInvestigator
--	20160820 by kjt: Revised to use new table schema, plus update Org and OrgR.
--	20191010 by kjt: Added logic to also load UC Path labor expenses from FISDataMart.dbo.AnotherLaborTransactions_Sept2019
--		as these expenses have already had their flags set and their FTE calculated.  They can just be loaded into the 
--		intermediate table.
--	20191126 by kjt: Revised to use AD419 database's copy of AnotherLaborTransactions_Sept2019
--  20191203 by kjt: Revised to union AnotherLaborTransactions and AnotherLaborTransactions_Sept2019, plus
--		populate the names from AnotherLaborTransactions.
--	20201028 by kjt: Revised FTE calculation to use SUM(ERN_DERIVED_PERCENT)/12 as per Shannon Tanguay.
--		Also updated to use [dbo].[RICE_UC_KRIM_PERSON_V] Vs. PPS Persons.
--	20201106 by kjt: Revised to use RICE_UC_KRIM_PERSON Vs. RICE_UC_KRIM_PERSON_V.
--	20201119 by kjt: Fix issues with sub-account join as UCP has ' ' instead of '-----' for default
--		sub accounts and was omitting everything but those accounts with sub accounts present.
--		Also added logic to populate PI name for account RMFINAW.
--	20201125 by lkt: Added MAX(PrincipalInvestigator) to inner join to keep from duplicating
--		expenses due to multiple PI names.
--	20211104 by kjt: Added reporting year to where clause as AnotherLaborTransactions may contain records for multiple years.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadPPSExpensesFor204Projects] 
	@FiscalYear int = 2020,
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
      ,[Org]
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[Amount]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
      ,[FTE]
	)
	SELECT 
	   [Chart]
      ,[Account]
      ,[SubAccount]
      ,[PrincipalInvestigator]
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
      --,[OrgR]
      ,[Org]
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,SUM([Amount]) Amount
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
      ,SUM([FTE]) FTE
	FROM (
		SELECT 
		   t0.[Chart]
		  ,t0.[Account]
		  ,t0.[SubAccount]
		  ,PrincipalInvestigator
		  ,[ObjConsol]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		  ,[Org]
		  ,[EmployeeID]
		 -- ,[EmployeeName]
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
				--CASE 
				--	WHEN [RateTypeCd] = ''H'' THEN SUM(Amount) / ([PayRate] * 2088)
				--	ELSE SUM(Amount) / [PayRate] / 12 END
				SUM(ERN_DERIVED_PERCENT)/12
			ELSE 0
			END) AS FTE
	  --INTO PPS_ExpensesFor204Projects
	  FROM [dbo].[AnotherLaborTransactions] t0
	  INNER JOIN (
		SELECT t1.Chart, t1.Account, t1.SubAccount, COALESCE(t2.PrincipalInvestigatorName, MAX(t1.PrincipalInvestigator)) PrincipalInvestigator,
			ConsolidationCode
		FROM [dbo].[All204NonExpiredExpensesV] t1
		LEFT OUTER JOIN FISDataMart.dbo.AccountsUFY t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
		GROUP BY t1.Chart, t1.Account, t1.SubAccount, t2.PrincipalInvestigatorName, 
			ConsolidationCode
		) t1 ON 
			t0.Chart = t1.Chart AND 
			t0.Account = t1.Account AND 
			REPLACE(t0.SubAccount, '' '', ''-----'') = t1.SubAccount AND  
			t0.ObjConsol = t1.ConsolidationCode
	  INNER JOIN ConsolCodesForLaborTransactions t2 ON t0.ObjConsol = t2.Obj_Consolidatn_Num
	  WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
	  GROUP BY 
		 t0.[Chart]
		,t0.[Account]
		,t0.[SubAccount]
		,PrincipalInvestigator
		,[ObjConsol]
		,[FinanceDocTypeCd]
		,[DosCd]
		,[Org]
		,[EmployeeID]
	   -- ,[EmployeeName]
		,[TitleCd]
		,[RateTypeCd]
		,[Payrate]
		,[FringeBenefitSalaryCd]
		,t0.[AnnualReportCode]

	) t1
	GROUP BY  
	   [Chart]
      ,[Account]
      ,[SubAccount]
      ,[PrincipalInvestigator]
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
      --,[OrgR]
      ,[Org]
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
'
		IF @IsDebug = 1
			PRINT @TSQL
		ELSE
			EXEC(@TSQL)

	-- 20191203 by kjt:  Added new logic for populating the EmployeeName
	--
	SELECT @TSQL = '
	UPDATE [dbo].PPS_ExpensesFor204Projects
	SET EmployeeName = t2.EmployeeName
	FROM [dbo].PPS_ExpensesFor204Projects t1
	LEFT OUTER JOIN (
		SELECT DISTINCT EmployeeID, EmployeeName
		FROM [dbo].[AnotherLaborTransactions]
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
	) t2 ON t1.EmployeeID = t2.EmployeeID
	WHERE t1.EmployeeName IS NULL AND t2.EmployeeName IS NOT NULL
	'
		IF @IsDebug = 1
			PRINT @TSQL
		ELSE
			EXEC(@TSQL)

	SELECT @TSQL = '
  -- Update the OrgR:
  UPDATE [dbo].PPS_ExpensesFor204Projects
  SET OrgR = t2.OrgR
  FROM [dbo].PPS_ExpensesFor204Projects t1
  INNER JOIN [dbo].[All204NonExpiredExpensesV] t2 ON 
	t1.Chart = t2.Chart and 
	t1.Account = t2.Account AND 
	REPLACE(t1.SubAccount, '' '', ''-----'') = t2.SubAccount 
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = '
	-- Update missing PI name for Kelsey Wood on account RMFINAW:

	UPDATE [dbo].[PPS_ExpensesFor204Projects] 
	SET PrincipalInvestigator = ''WOOD,KELSEY JORDAN''
	WHERE Chart = ''3'' AND Account =	''RMFINAW'' AND PrincipalInvestigator IS NULL
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END