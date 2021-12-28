
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
		@FiscalYear = 2021, @IsDebug = 0

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
-- 20160809 by kjt: Added PrincipalInvestigator
-- 20171025 by kjt: Added @FiscalYear as parameter.
--	Added additional joins to ensure only 1 record was returned
--	due to Org, OrgR, and Principal Investigator changes through the year.
-- 20171204 by kjt: Addeed additional Left Outer Joins and logic that ensures the 
--	OrgR is active and present in the reporting orgs table.  If not, we pull the OrgR
--	we've already validated (or remapped) in UFY_FFY_FIS_Expenses table.  This is the best way
--	to ensure we haven't ended up with duplicate transactions, which was the issue when I
--	attempted to use the UFY_FFY_FIS_Expenses table as a source for populating OrgRs for 
--	the Labor Transactions (PPS) expenses.
-- 20181108 by kjt: Issues with the above logic because it was pulling AAES instead of
-- KVSP for account KVS2644, because it was listed as the Org in 2018.  It was later changed,
--	but the logic selected AAES since it wasn't excluded.  It now it is.
--	20191010 by kjt: Added logic to also load UC Path labor expenses from FISDataMart.dbo.AnotherLaborTransactions_Sept2019
--		as these expenses have already had their flags set and their FTE calculated.  They can just be loaded into the 
--		intermediate table.
-- 20191109 by kjt: Fixed several syntax errors, i.e. missing commas and periods.
--	20191126 by kjt: Revised to use AD419 database's copy of AnotherLaborTransactions_Sept2019
--  20191203 by kjt: Revised to union AnotherLaborTransactions and AnotherLaborTransactions_Sept2019, plus
--		populate the names from AnotherLaborTransactions.
-- 20201106 by kjt: Revised to use new FTE calculation method as per Shannon Tanguay, plus changed to use 
--	[dbo].[RICE_UC_KRIM_PERSON] Vs. Persons
--	20211104 by kjt: Added reporting year to where clause as AnotherLaborTransactions may contain records for multiple years.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadPPSExpensesForNon204Projects] 
	@FiscalYear int = 2020,
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
TRUNCATE TABLE [dbo].PPS_ExpensesForNon204Projects
INSERT INTO [dbo].PPS_ExpensesForNon204Projects (
	  [Chart]
      ,[Account]
      ,[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
	  ,OrgR
	  ,Org
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,Amount
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
	  ,FTE
	  ,SFN
)
SELECT [Chart]
      ,[Account]
      ,[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
	  ,OrgR
	  ,Org
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,SUM([Amount]) Amount
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
	  ,SUM(FTE) FTE
	  ,SFN
FROM (
		SELECT 
		   t0.[Chart]
		  ,t0.[Account]
		  ,[SubAccount]
		  ,t1.PrincipalInvestigator
		  ,[ObjConsol]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		   ,CASE WHEN t4.OrgR IS NULL	--Use the OrgR we already validated in the UFY_FFY_FIS_Expenses OrgR
				THEN t5.OrgR			--	check if the standard OrgR finding logic comes back with one
				ELSE t1.OrgR			--	that''s not an active OrgR in the reporting orgs table. 
		   END OrgR
		  ,t1.Org
		  ,[EmployeeID]
		  --,[EmployeeName]
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
			END) AS FTE,
			SFN
		--INTO PPS_ExpensesForNon204Projects
		FROM [dbo].[AnotherLaborTransactions] t0
		INNER JOIN (
			SELECT t1.Chart, t1.Account, t1.ConsolidationCode, 
				COALESCE(t2.PrincipalInvestigatorName, t4.PrincipalInvestigatorName) PrincipalInvestigator,
				SFN, COALESCE(t3.OrgR, t5.OrgR) OrgR, COALESCE(t2.Org, t4.Org) Org
			FROM [dbo].FFY_Non204ExpensesV t1
			LEFT OUTER JOIN FisDataMart.Dbo.Accounts t2 ON t1.Chart = t2.Chart and T1.Account = t2.Account AND (t2.Year = ' + CONVERT(varchar(4), @FiscalYear) + ' and t2.period = ''--'') AND t2.Org != ''AAES''
			LEFT OUTER JOIN FisDataMart.Dbo.Accounts t4 ON t1.Chart = t4.Chart and T1.Account = t4.Account AND (t4.Year = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' and t4.period = ''--'') AND t4.Org != ''AAES''
			LEFT OUTER JOIN UFYOrganizationsOrgR_v t3 ON t1.Chart = t3.Chart and COALESCE(t2.Org, t4.Org) = t3.Org
			LEFT OUTER JOIN FisDataMart.Dbo.OrganizationsV t5 ON t1.Chart = t5.Chart and COALESCE(t2.Org, t4.Org) = t5.Org AND t5.Year = 9999 AND t5.Period = ''--''
			GROUP BY t1.Chart, t1.Account, t1.ConsolidationCode, COALESCE(t2.PrincipalInvestigatorName, t4.PrincipalInvestigatorName), 
				SFN, COALESCE(t2.Org, t4.Org), COALESCE(t3.OrgR, t5.OrgR)
		) t1 ON t0.Chart = t1.Chart AND t0.Account = t1.Account AND t0.ObjConsol = t1.ConsolidationCode
		INNER JOIN ConsolCodesForLaborTransactions t2 ON t0.ObjConsol = t2.Obj_Consolidatn_Num
		-- 2017-12-04 by kjt: New joins to ''Fix'' bad reporting OrgRs:
		LEFT OUTER JOIN ReportingOrg t4 ON t1.OrgR = t4.OrgR AND t4.IsActive = 1
		LEFT OUTER JOIN (
			SELECT DISTINCT Chart, Account, Org, OrgR
			FROM UFY_FFY_FIS_Expenses
		--
		) t5 ON t1.Chart = t5.Chart AND t1.Account = t5.Account AND t1.Org = t5.Org 
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
		GROUP BY 
			   t0.[Chart]
			  ,t0.[Account]
			  ,[SubAccount]
			  ,t1.PrincipalInvestigator
			  ,[ObjConsol]
			  ,[FinanceDocTypeCd]
			  ,[DosCd]
			  ,t1.OrgR
			  ,t1.Org
			  ,[EmployeeID]
			 -- ,[EmployeeName]
			  ,[TitleCd]
			  ,[RateTypeCd]
			  ,[Payrate]
			  ,[FringeBenefitSalaryCd]
			  ,t0.[AnnualReportCode]
			  ,SFN
			  ,t4.OrgR
			  ,t5.OrgR
	'
	---------------------------------------------------------------------
	-- Additional logic to load records from AnotherLaborTransactions_Sept2019:
	IF @FiscalYear = 2019
	BEGIN
		SELECT @TSQL += '
		UNION

		SELECT t0.[Chart]
			  ,t0.[Account]
			  ,[SubAccount]
			  ,t1.PrincipalInvestigator
			  ,[ObjConsol]
			  ,[FinanceDocTypeCd]
			  ,[DosCd]
			   ,CASE WHEN t4.OrgR IS NULL	--Use the OrgR we already validated in the UFY_FFY_FIS_Expenses OrgR
					THEN t5.OrgR			--	check if the standard OrgR finding logic comes back with one
					ELSE t1.OrgR			--	that''s not an active OrgR in the reporting orgs table. 
			   END OrgR
			  ,t1.Org
			  ,[EmployeeID]
			  --,[EmployeeName]
			  ,[TitleCd]
			  ,[RateTypeCd]
			  ,[Payrate]
			  ,SUM([Amount]) Amount
			  ,[FringeBenefitSalaryCd]
			  ,t0.[AnnualReportCode]
			 -- ,CONVERT(DECIMAL(18,4),CASE WHEN [FinanceDocTypeCd] IN (SELECT DocumentType FROM dbo.FinanceDocTypesForFTECalc)
			 -- AND 
				--	ObjConsol IN (select Obj_Consolidatn_Num FROM ConsolCodesForFTECalc) AND 
				--	[PayRate] <> 0 AND 
				--	DosCd IN (SELECT DOS_Code FROM dbo.DOSCodes)
				--THEN 
				--	CASE 
				--		WHEN [RateTypeCd] = ''H'' THEN SUM(Amount) / ([PayRate] * 2088)
				--		ELSE SUM(Amount) / [PayRate] / 12 END
				--ELSE 0
				--END) AS FTE,
				,SUM(CalculatedFTE) AS FTE
				,SFN
		--INTO PPS_ExpensesForNon204Projects
		FROM [dbo].[AnotherLaborTransactions_Sept2019] t0
		INNER JOIN (
			SELECT t1.Chart, t1.Account, t1.ConsolidationCode, 
				COALESCE(t2.PrincipalInvestigatorName, t4.PrincipalInvestigatorName) PrincipalInvestigator,
				SFN, COALESCE(t3.OrgR, t5.OrgR) OrgR, COALESCE(t2.Org, t4.Org) Org
			FROM [dbo].FFY_Non204ExpensesV t1
			LEFT OUTER JOIN FisDataMart.Dbo.Accounts t2 ON t1.Chart = t2.Chart and T1.Account = t2.Account AND (t2.Year = ' + CONVERT(varchar(4), @FiscalYear) + ' and t2.period = ''--'') AND t2.Org != ''AAES''
			LEFT OUTER JOIN FisDataMart.Dbo.Accounts t4 ON t1.Chart = t4.Chart and T1.Account = t4.Account AND (t4.Year = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' and t4.period = ''--'') AND t4.Org != ''AAES''
			LEFT OUTER JOIN UFYOrganizationsOrgR_v t3 ON t1.Chart = t3.Chart and COALESCE(t2.Org, t4.Org) = t3.Org
			LEFT OUTER JOIN FisDataMart.Dbo.OrganizationsV t5 ON t1.Chart = t5.Chart and COALESCE(t2.Org, t4.Org) = t5.Org AND t5.Year = 9999 AND t5.Period = ''--''
			GROUP BY t1.Chart, t1.Account, t1.ConsolidationCode, COALESCE(t2.PrincipalInvestigatorName, t4.PrincipalInvestigatorName), 
				SFN, COALESCE(t2.Org, t4.Org), COALESCE(t3.OrgR, t5.OrgR)
		) t1 ON t0.Chart = t1.Chart AND t0.Account = t1.Account AND t0.ObjConsol = t1.ConsolidationCode
		INNER JOIN ConsolCodesForLaborTransactions t2 ON t0.ObjConsol = t2.Obj_Consolidatn_Num
		-- 2017-12-04 by kjt: New joins to ''Fix'' bad reporting OrgRs:
		LEFT OUTER JOIN ReportingOrg t4 ON t1.OrgR = t4.OrgR AND t4.IsActive = 1
		LEFT OUTER JOIN (
			SELECT DISTINCT Chart, Account, Org, OrgR
			FROM UFY_FFY_FIS_Expenses
		--
		) t5 ON t1.Chart = t5.Chart AND t1.Account = t5.Account AND t1.Org = t5.Org 
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
		GROUP BY 
			   t0.[Chart]
			  ,t0.[Account]
			  ,[SubAccount]
			  ,t1.PrincipalInvestigator
			  ,[ObjConsol]
			  ,[FinanceDocTypeCd]
			  ,[DosCd]
			  ,t1.OrgR
			  ,t1.Org
			  ,[EmployeeID]
			 -- ,[EmployeeName]
			  ,[TitleCd]
			  ,[RateTypeCd]
			  ,[Payrate]
			  ,[FringeBenefitSalaryCd]
			  ,t0.[AnnualReportCode]
			  ,SFN
			  ,t4.OrgR
			  ,t5.OrgR
'
	END
	--
	-- End of additions for adding for AnotherLaborTranslations_Sept2019
	---------------------------------------------------------------------
	SELECT @TSQL += '
	) t1
	GROUP BY 
	   [Chart]
      ,[Account]
      ,[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
	  ,OrgR
	  ,Org
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
	  ,SFN
	ORDER BY 
	   [Chart]
      ,[Account]
      ,[SubAccount]
	  ,PrincipalInvestigator
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
	  ,OrgR
	  ,Org
      ,[EmployeeID]
      --,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
	  ,SFN
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL) 

	-- 20191203 by kjt:  Added new logic for populating the EmployeeName:
	--
	SELECT @TSQL = '
	UPDATE [dbo].PPS_ExpensesForNon204Projects
	SET EmployeeName ='
	
	IF @FiscalYear = 2019 
	BEGIN		
		SELECT @TSQL += ' COALESCE(t2.EmployeeName, t3.EmployeeName) 
	'
	END
	ELSE
	BEGIN
		SELECT @TSQL += ' t2.EmployeeName ' 
	END
	
	SELECT @TSQL += 
   'FROM [dbo].PPS_ExpensesForNon204Projects t1
	LEFT OUTER JOIN (
		SELECT DISTINCT EmployeeID, EmployeeName
		FROM [dbo].[AnotherLaborTransactions]
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
	) t2 ON t1.EmployeeID = t2.EmployeeID
	'
	IF @FiscalYear = 2019 
	BEGIN		
	SELECT @TSQL += 'LEFT OUTER JOIN (
		SELECT DISTINCT EmployeeID, EmployeeName
		FROM [dbo].[AnotherLaborTransactions_Sept2019] 
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
	) t3 ON t1.EmployeeID = t3.EmployeeID
'
	END
		IF @IsDebug = 1
			PRINT @TSQL
		ELSE
			EXEC(@TSQL)

	-- 20191010 by kjt: Move this logic until after adding the ...Sept2019 logic.

	SELECT @TSQL = '
  update [dbo].PPS_ExpensesForNon204Projects
  set EmployeeName = t2.PERSON_NM
  FROM [dbo].PPS_ExpensesForNon204Projects t1
  INNER JOIN [PPSDatamart].[dbo].[RICE_UC_KRIM_PERSON_V] t2 ON t1.EmployeeID = t2.Employee_ID 
  WHERE t1.employeeName IS NULL
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)  
END