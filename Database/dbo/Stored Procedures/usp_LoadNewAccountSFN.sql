-- =============================================
-- Author:		Ken Taylor
-- Create date: July 11, 2016
-- Description:	Load the NewAccountSFN table.
-- The main purpose of this table is two-fold:
-- 1. provide the necessary criteria for determining the SFN for CA&ES non-204 projects, and
-- 2. provide the necassary for determining the corresponding project 20x project to match the 
-- expenses to.
--
-- Prerequisites:
-- 1. The ARCs for the FFY must have already been determined.
-- 2. FFY Expenses by ARC must have already been loaded in order for the update of
-- "IsAccountInFianacialData" to work.
-- Usage:
/*
USE AD419
GO

EXEC usp_LoadNewAccountSFN @FiscalYear = 2015
GO

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadNewAccountSFN] 
	@FiscalYear int = 2015
AS
BEGIN
	-- DECLARE @FiscalYear int = 2015

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	TRUNCATE TABLE NewAccountSFN

	INSERT INTO [AD419].[dbo].NewAccountSFN(
		   [Chart]
		  ,[Account]
		  ,[Org]
		  ,[IsCE]
		  ,[SFN]
		  ,[CFDANum]
		  ,[OpFundGroupCode]
		  ,[OpFundNum]
		  ,[FederalAgencyCode]
		  ,[NIHDocNum]
		  ,[SponsorCategoryCode]
		  ,[SponsorCode]
		  ,[Accounts_AwardNum]
		  ,[OpFund_AwardNum]
		  ,[ExpirationDate]
		  ,[AwardEndDate]
		  ,[IsAccountInFinancialData]
	  )

	SELECT 
		Limit1.Chart, 
		Limit1.Account,
		Limit1.Org, 
		Limit1.isCE,
		CONVERT(varchar(5), NULL) AS SFN,
		Limit1.CFDANum, 
		Limit1.OpFundGroupCode, 
		Limit1.OpFundNum,
		Limit1.FederalAgencyCode, 
		Limit1.NIHDocNum, 
		Limit1.SponsorCategoryCode, 
		Limit1.SponsorCode,
		CONVERT (varchar(50), NULL) AS Accounts_AwardNum,
		CONVERT (varchar(50), NULL) AS OpFund_AwardNum,
		Limit1.ExpirationDate,
		Limit1.AwardEndDate,
		CONVERT (bit, NULL) AS IsAccountInFinancialData
--Into NewAccountSFN
	FROM (
		SELECT DISTINCT Extent1.Chart, Extent1.Account
		FROM         [FISDataMart].[dbo].[Accounts] Extent1 LEFT OUTER JOIN
					 [FISDataMart].[dbo].[ARCCodes] ARC_Codes ON Extent1.AnnualReportCode like ARC_Codes.ARCCode
		where (
					(Year = @FiscalYear AND Period BETWEEN '04' AND '13') OR 
					(Year = @FiscalYear + 1 AND Period BETWEEN '01' AND '03') OR
					(Year = 9999 AND Period = '--')
			   )
			  AND Extent1.HigherEdFuncCode not like 'PROV' -- Exclude the PROV accounts.
			  AND Extent1.OpFundGroupCode NOT LIKE '600000' -- BALANCE SHEET
		 ) AS Distinct1
		OUTER APPLY (
			SELECT top(1)
		Account2.Year, 
		Account2.Period, 
		Account2.Chart, 
		Account2.Org, 
		Account2.Account, 
		Account2.isCE,
		Account2.CFDANum, 
		Account2.OpFundGroupCode, 
		Account2.FederalAgencyCode, 
		Account2.NIHDocNum, 
		Account2.SponsorCode, 
		Account2.SponsorCategoryCode, 
		Account2.OpFundNum,
		Account2.ExpirationDate,
		Account2.AwardEndDate
	 FROM (
		SELECT 
			Extent2.Year, Extent2.Period, 
			Extent2.Chart, Extent2.Org, 
			Extent2.Account, 
			Extent2.CFDANum, 
			Extent2.OpFundGroupCode, 
			Extent2.FederalAgencyCode, 
			Extent2.NIHDocNum, 
			Extent2.SponsorCode, 
			Extent2.SponsorCategoryCode, 
			Extent2.OpFundNum,
			(CASE WHEN ((LEFT(Extent2.A11AcctNum,2) BETWEEN '44' AND '59') OR Extent2.HigherEdFuncCode = 'ORES') AND Extent2.Chart = 'L' THEN 1
		  WHEN ((LEFT(Extent2.A11AcctNum,2) = '62' OR Extent2.HigherEdFuncCode = 'PBSV') ) THEN 1
		  ELSE 0 END)  AS isCE
		  , Extent2.ExpirationDate,
		  Extent2.AwardEndDate
	 FROM FISDataMart.dbo.Accounts AS Extent2
	 WHERE (Distinct1.Chart = extent2.Chart AND Distinct1.Account = Extent2.Account)
	 ) AS Account2

	 ORDER BY Account2.Year DESC, Account2.Period, Account2.Chart, Account2.Account) AS Limit1

	 UPDATE NewAccountSFN
	 SET IsAccountInFinancialData = 1 
	 FROM NewAccountSFN t1
	 INNER JOIN FFY_ExpensesByARC t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account

	 UPDATE NewAccountSFN
	 SET  IsAccountInFinancialData = 0 
	 where IsAccountInFinancialData IS NULL

   
END