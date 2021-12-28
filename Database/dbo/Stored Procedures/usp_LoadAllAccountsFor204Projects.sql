
-- =============================================
-- Author:		Ken Taylor
-- Create date: July 11, 2016
-- Description:	Loads the "AllAccountsFor204Projects table.
-- Contains chart, and account for every CA&ES 204 project.  
-- These chart/account combinations were determined using OpFundNum, regardless of ARC as some of the accounts
-- for 204 projects are outside of our ARCs.
-- This AllAccountsFor204Projects table is used for matching account AwardNumber or OPFund Award number
-- its corresponding 204 project.
-- Prerequisites:
-- 1. The AllProjectsNew table must have been loaded.
-- 2. The ARC codes table must have been already loaded.(This is only used to set the the ExcludedByARC flag)
-- 3. The ARC code/Account exclusions table must have been loaded. (This is only used to set the the ExcludedByAccount flag)
-- 4. The AnotherLaborTranslations table must have been loaded so that the FTE can be updated.
-- Usage:
/*
	USE AD419
	GO

	EXEC usp_LoadAllAccountsFor204Projects @FiscalYear = 2021
	GO
*/
-- Modifications:
--	20160728 by kjt: Simplified logic and broke logic into several sub-sections to simplify and increase performance.
--	20160812 by kjt: Added logic to update the FTE field.
--	20160820 by kjt: Revised comments to reflect that AnotherLaborTransactions must be loaded first.
--	20171016 by kjt: Revised OrgR update join to use UFYOrganizationsOrgR_v as OrgXOrgR ended up leaving
--		a few OrgRs blank.
--	20201013 by kjt: Revised to use UC Path as a data source for Labor Transctions.
--	20201926 by kjt: Revised to use DERIVED PERCENT as FTE as per Shannon Tanguay 2020-10-21 as this
--		value appears to be the most accurate in terms of actual FTE.  Also removed PayRate as
--		part of determination whether or not to calculate FTE.
--	20201124 by kjt: Added section to update the OrgR from the Account's OrgR to "AIND' for all (204) projects
--		where the project number is like '%IND%'.
-- 20210422 by kjt: Revised to include OP Fund chart number as the same OP Funds are being used for
--		multiple charts, causing erroneous matches were being returned for the majority of chart L 
--		accounts belonging to ANR or Vice Chancellor Orgs.
--	20211008 by kjt: Modified procedure to use AnotherLaborTransactions instead of re-pulling
--		labor data, as we are now loading ALL labor records for DVCMP and UCANR.  This also required
--		filtering on the 204 accounts list. 
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadAllAccountsFor204Projects] 
	@FiscalYear int = 2021
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- This in-memory table holds a list of OP(UC) Funds we're going to use to search
	-- for chart and accounts by. 
	DECLARE @Distinct1 TABLE (Chart varchar(2), Account varchar(7), AnnualReportCode varchar(6), IsUCD bit, ExcludedByARC bit, ExcludedByAccount bit)
	INSERT INTO @Distinct1
	SELECT DISTINCT Extent1.Chart, Extent1.Account, Extent1.AnnualReportCode, IsUCD,
	CASE WHEN AC.ARCCode IS NULL THEN 1 ELSE 0 END AS ExcludedBYARC,
	CASE WHEN ACE.Account IS NULL THEN 0 ELSE 1 END AS ExcludedByAccount
	FROM         [FISDataMart].[dbo].[Accounts] Extent1  
	INNER JOIN dbo.udf_Get204OpFundNumsForFiscalYear(@FiscalYear) ARC_Codes ON 
					Extent1.Chart = ARC_Codes.Chart AND
					Extent1.OpFundNum like ARC_Codes.OpFundNum 
	LEFT OUTER JOIN FISDataMart.dbo.ARCCodes AC ON 
		Extent1.AnnualReportCode = AC.ARCCode 
	LEFT OUTER JOIN dbo.udf_ArcCodeAccountExclusionsForFiscalYear(@FiscalYear) ACE ON 
		Extent1.Chart = ACE.Chart AND Extent1.Account = ACE.Account
	WHERE (
	-- Use the 9999 year because it will have a more complete list of accounts, meaning it will cover
	-- accounts for some projects which would have otherwise be excluded.
				Year = 9999 AND Period = '--'
			)
			AND Extent1.HigherEdFuncCode not like 'PROV' -- Exclude the PROV accounts.
	/*
195 rows
0:04
*/
    DECLARE @Limit1 TABLE(AnnualReportCode varchar(6), Chart varchar(2), Account varchar(7), Org varchar(4), OpFundNum varchar(6),
	IsUCD bit, ExcludedByARC bit, ExcludedByAccount bit)
    --DROP TABLE Limit1
	INSERT INTO @Limit1
	SELECT Limit1.AnnualReportCode, Limit1.Chart, Limit1.Account, Limit1.Org, Limit1.OpFundNum, 
		IsUCD, ExcludedByARC, ExcludedByAccount
	FROM 
	@Distinct1 Distinct1
	OUTER APPLY (
	SELECT top(1)
		Account2.Year, 
		Account2.Period, 
		Account2.Chart, 
		Account2.Org, 
		Account2.Account, 
		Account2.OpFundNum,
		Account2.AnnualReportCode
	 FROM (
		SELECT 
			Extent2.Year, Extent2.Period, 
			Extent2.Chart, Extent2.Org, 
			Extent2.Account, 
			Extent2.OpFundNum,
			Extent2.AnnualReportCode
	 FROM FISDataMart.dbo.Accounts AS Extent2
	 WHERE (Distinct1.Chart = extent2.Chart AND Distinct1.Account = Extent2.Account)
	 ) AS Account2
	 ORDER BY Account2.Year DESC, Account2.Period, Account2.Chart, Account2.Account) AS Limit1

	 /*
	 195 rows
	 02:29
	 */

	 DECLARE @Projects TABLE ( 
	   [AccessionNumber] varchar(7)
      ,[ProjectNumber] varchar(24)
      ,[AwardNumber]  varchar(20)
      ,OpFundNum varchar(6)
	  ,ProjectEndDate datetime2
	  ,AnnualReportCode varchar(6)
	  ,Chart varchar(2)
	  ,Account varchar(7)
      ,IsExpired bit
	  )

	INSERT INTO @Projects
    SELECT DISTINCT 
       [AccessionNumber]
      ,[ProjectNumber]
      ,[AwardNumber] 
      ,COALESCE(F.FundNum, A.OpFundNum) OpFundNum
	  ,ProjectEndDate
	  ,A.AnnualReportCode
	  ,A.Chart, A.Account--, OrganizationName
      ,CASE WHEN ProjectEndDate < CONVERT(varchar(4), @FiscalYear -1) + '-10-01' THEN 1 ELSE 0 END AS IsExpired
  FROM dbo.udf_AllProjectsNewForFiscalYear(@FiscalYear) P 
  LEFT OUTER JOIN FISDataMart.dbo.OPFund F ON (
	REPLACE(P.AwardNumber, '-', '') = REPLACE(F.AwardNum, '-','') OR
	F.FundName LIKE '%' + REPLACE(P.AwardNumber, '-', '') + '%'
	) AND F.Year = 9999 AND F.Period = '--'
  LEFT OUTER JOIN FISDataMart.dbo.Accounts A ON REPLACE(P.AwardNumber, '-', '') = REPLACE(A.AwardNum, '-','') AND A.Year = 9999 AND A.Period = '--'
  WHERE [AwardNumber] IS NOT NULL AND RIGHT(RTRIM([ProjectNumber]),2) IN ('CG','OG','SG')

  /*
  208 records
  0:06
  */

	TRUNCATE TABLE AllAccountsFor204Projects
	INSERT INTO AllAccountsFor204Projects
	select AccessionNumber, ProjectNumber, AwardNumber, limit1.AnnualReportCode, limit1.Chart, limit1.Account, 
		CONVERT(varchar(4), NULL) OrgR, 
		Limit1.Org, '204' AS SFN, Limit1.OpFundNum,  ProjectEndDate, isExpired, ExcludedByARC, ExcludedByAccount, 
		CONVERT(bit, 0) IsAccountInFinancialData, CONVERT(bit, 0) As IsAssociable, IsUCD,CONVERT(money, NULL) AS Expenses,
		CONVERT(decimal(18,4), NULL) AS FTE
	from @limit1 Limit1
	LEFT OUTER JOIN @Projects Projects1 ON Limit1.OpFundNum = Projects1.OpFundNum
	GROUP BY Limit1.OpFundNum, Limit1.chart, Limit1.Account, Limit1.AnnualReportCode, Limit1.Org, AccessionNumber, ProjectNumber, AwardNumber, ProjectEndDate, isExpired, ExcludedByARC, ExcludedByAccount, IsUCD
	ORDER BY AccessionNumber, Limit1.Chart, Limit1.Account

	UPDATE AllAccountsFor204Projects
	SET expenses = t1.Expenses
	FROM (
	SELECT t1.Chart, t1.AccountNum Account, SUM(EXPEND) Expenses
	FROM FISDatamart.dbo.BalanceSummaryV t1
	INNER JOIN AllAccountsFor204Projects t2 ON t1.Chart = t2.Chart AND t1.AccountNum = t2.Account
	WHERE ((FiscalYear = @FiscalYear AND FiscalPeriod BETWEEN '04' AND '13') OR (FiscalYear = @FiscalYear + 1 AND FiscalPeriod BETWEEN '01' AND '03'))
		AND TransBalanceType = 'AC' AND HigherEdFunctionCode NOT LIKE 'PROV'
	GROUP BY t1.Chart, T1.AccountNum
	) t1 
	INNER JOIN AllAccountsFor204Projects t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account


	UPDATE AllAccountsFor204Projects
	SET IsAccountInFinancialData = 1
	WHERE Expenses IS NOT NULL

	-- I do not think this bit is useful at this level, because it should apply to the whole project
	UPDATE AllAccountsFor204Projects
	SET IsAssociable = 1
	WHERE Expenses > 100 AND Expenses IS NOT NULL AND IsExpired = 0

	-- 20171016 by kjt: Revised join from OrgXOrgR to UFYOrganizationsOrgR_v because a handful of OrgRs
	--	were not being populated.
	UPDATE AllAccountsFor204Projects
	SET OrgR = t2.OrgR
	FROM AllAccountsFor204Projects t1
	INNER JOIN UFYOrganizationsOrgR_v t2 ON t1.Org = t2.Org AND t1.Chart = t2.Chart

	-- 20201124 by kjt: There are now several 204 "IND" projects, which need to have their OrgRs
	-- changed from ADNO or whatever the expenses's OrgR is to the project's OrgR of 'AIND'.

	UPDATE AllAccountsFor204Projects
	SET OrgR = 'AIND'
	WHERE ProjectNumber LIKE '%IND%'

	----------------------------------------------------------------------------------------
	-- 20211008 by kjt: This section is no longer required as we are using AnotherLaborTransactions
	--	directly since in now contains All labor records.
	---- New section for working with UCPath:
	---- Load the 204LaborTransactionsTempTable since we excluded expenses outside of our ARCs:

	--DECLARE @204LaborTransactionsTempTable TABLE 
	--(
	--	[LaborTransactionId] [varchar](125) NOT NULL,
	--	[Chart] [varchar](2) NULL,
	--	[Account] [varchar](7) NULL,
	--	[SubAccount] [varchar](5) NULL,
	--	[Org] [varchar](4) NULL,
	--	[ObjConsol] [varchar](4) NULL,
	--	[Object] [varchar](4) NOT NULL,
	--	[FinanceDocTypeCd] [varchar](4) NULL,
	--	[DosCd] [varchar](3) NULL,
	--	[EmployeeID] [varchar](10) NULL,
	--	[EmployeeName] [varchar](100) NULL,
	--	[POSITION_NBR] [nvarchar](8) NULL,
	--	[EFFDT] [datetime2](7) NULL,
	--	[RateTypeCd] [varchar](1) NULL,
	--	[Hours] [numeric](18, 6) NOT NULL,
	--	[Amount] [money] NULL,
	--	[Payrate] [numeric](17, 4) NULL,
	--	[CalculatedFTE] [numeric](9, 6) NULL,
	--	[PayPeriodEndDate] [datetime2](7) NULL,
	--	[FringeBenefitSalaryCd] [varchar](1) NULL,
	--	[AnnualReportCode] [varchar](6) NULL,
	--	[ReportingYear] [int] NULL,
	--	[OrgId] varchar(4) NULL,
	--	[ERN_DERIVED_PERCENT] numeric(7,4) NULL
	--)

	--INSERT INTO @204LaborTransactionsTempTable
	--EXEC [dbo].[usp_Get204LaborExpenseTransactions]
	--	@FiscalYear = @FiscalYear

	----

	UPDATE [dbo].[AllAccountsFor204Projects]
	SET FTE = t2.FTE
	FROM 
	[dbo].[AllAccountsFor204Projects] t1
	INNER JOIN 
	(
		SELECT Chart, Account, SUM(FTE) FTE
	FROM
	(
	-- This section wase modified for UC Path becase we're only pulling in labor records 
	-- for our ARCs when we load AnotherLaborTransactions, and many of the 204 expense accounts
	-- are outside of our ARCS.  Shannon and I verified that the data on these outside ARCs 
	-- is indeed valid because of the way that Grad students are paid, plus other anomalies, 
	-- mis-coding ARCs, etc. Therefore, it made more sense just to reload the labor data just
	-- for these 204 accounts as opposed to expanding the AnotherTransactionsLoading to include
	-- everything.  Our ARC filtered load results in abount 540,000 records, as opposed to the
	-- 6 million records that are present in the salary and fringe tables combined.
	-- Lastly, the below processing takes less than a minute to complete due to the restricted
	-- chart and account list used in the where clause.

		SELECT
		   t0.[Chart]
		  ,t0.[Account]
		 ,CONVERT(DECIMAL(18,4),CASE WHEN [FinanceDocTypeCd] IN (SELECT DocumentType FROM dbo.FinanceDocTypesForFTECalc)
		  AND 
		  --	Revised 20201026 by kjt to use DerivedPercent:
				ObjConsol IN (select Obj_Consolidatn_Num FROM ConsolCodesForFTECalc) AND 
				--[PayRate] <> 0 AND -- Payrate is a derived value with UCP as only hours and anount
									-- are present in the data.  Therefore, use hours instead:
				SUM(Hours) <> 0 AND -- Hours are always a non-zero vaule when FTE should be considered.
				DosCd IN (SELECT DOS_Code FROM dbo.DOSCodes)
			THEN 
				-- Revised to ALWAYS use ERN_DERIVED_PERCENT as this is the only
				--  field available to accurately calculate FTE for both
				--  monthly and bi-weekly fractional, i.e. part-time employees:

				SUM(ERN_DERIVED_PERCENT)/12

				--CASE 
					--WHEN [RateTypeCd] = 'H' THEN SUM(Amount) / ([PayRate] * 2088)
					--ELSE SUM(Amount) / [PayRate] / 12 
				--END
			ELSE 0
			END) AS FTE
		-- 20211008 by kjt Modifications to use AnotherLaborTransactions table directly with
		--	with join for filtering for 204 accounts.
		FROM [dbo].[AnotherLaborTransactions] t0
		INNER JOIN (
			SELECT Chart, Account
			FROM [dbo].[AllAccountsFor204Projects]
			GROUP BY Chart, Account
		) t1 ON t0.Chart = t1.Chart AND t0.Account = t1.Account
		INNER JOIN ConsolCodesForLaborTransactions t2 ON t0.ObjConsol = t2.Obj_Consolidatn_Num
		WHERE t0.ReportingYear = @FiscalYear
		GROUP BY 
			 t0.[Chart]
			,t0.[Account]
			,[ObjConsol]
			,[FinanceDocTypeCd]
			,[DosCd]
			,[RateTypeCd]
			--,[Payrate]
		) t1
		GROUP BY Chart, Account
		) t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account

		UPDATE [dbo].[AllAccountsFor204Projects]
		SET FTE = 0 
		WHERE FTE IS NULL

END