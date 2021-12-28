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

EXEC usp_LoadNewAccountSFN @FiscalYear = 2016
GO

*/
-- Modifications:
--	20170321 by kjt: Added the columns that will facilitate classification using newly idenfied fields, such as 
-- SubFundGroupNum, SubFundGroupTypeCode, isNIH, isFederalFund, is204.
--	20171003 by kjt: Added HigherEdFuncCode "OAES" as per discussion with Shannon Tanguay 2017-10-02.
--	20171012 by kjt: Moved all of the update statements to usp_UpdateNewAccountSFN.
--	20171012 by kjt: Removed the 9999 fiscal year
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadNewAccountSFN] 
	@FiscalYear int = 2016
AS
BEGIN
	-- DECLARE @FiscalYear int = 2016

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
		  ,[SubFundGroupNum]
		  ,[SubFundGroupTypeCode]
		  ,[IsNIH]
		  ,[IsFederalFund]
		  ,[IsNIFA] --Populated from CFDA Numbers, etc.
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
		CONVERT (bit, NULL) AS IsAccountInFinancialData,
		Limit1.SubFundGroupNum,
		Limit1.SubFundGroupTypeCode,
		CONVERT (bit, NULL) AS IsNIH,
		CONVERT (bit, NULL) AS IsFederalFund,
		CONVERT (bit, NULL) AS IsNIFA
--Into NewAccountSFN
	FROM (
		SELECT DISTINCT Extent1.Chart, Extent1.Account
		FROM         [FISDataMart].[dbo].[Accounts] Extent1 LEFT OUTER JOIN
					 [FISDataMart].[dbo].[ARCCodes] ARC_Codes ON Extent1.AnnualReportCode like ARC_Codes.ARCCode
		where (
					(Year = @FiscalYear AND Period BETWEEN '04' AND '13') OR 
					(Year = @FiscalYear + 1 AND Period BETWEEN '01' AND '03')
					-- OR (Year = 9999 AND Period = '--')
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
		Account2.AwardEndDate,
		Account2.SubFundGroupNum,
		Account2.SubFundGroupTypeCode
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
			(CASE WHEN ((LEFT(Extent2.A11AcctNum,2) BETWEEN '44' AND '59') OR Extent2.HigherEdFuncCode IN ('ORES', 'OAES')) AND Extent2.Chart = 'L' THEN 1
		  WHEN ((LEFT(Extent2.A11AcctNum,2) = '62' OR Extent2.HigherEdFuncCode = 'PBSV') ) THEN 1
		  ELSE 0 END)  AS isCE
		  , Extent2.ExpirationDate,
		  Extent2.AwardEndDate,
		  Extent2.SubFundGroupNum, 
		  Extent2.SubFundGroupTypeCode
	 FROM FISDataMart.dbo.Accounts AS Extent2
	 WHERE (Distinct1.Chart = extent2.Chart AND Distinct1.Account = Extent2.Account)
	 ) AS Account2
	 ORDER BY Account2.Year DESC, Account2.Period, Account2.Chart, Account2.Account) AS Limit1

END