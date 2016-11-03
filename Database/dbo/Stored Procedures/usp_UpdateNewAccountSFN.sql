-- =============================================
-- Author:		Ken Taylor
-- Create date: July 11, 2016
-- Description:	Update NewAccountSFN's Award numbers and SFN
-- This procedure basically takes the place of the old Classify logic
-- and determines what SFN to assign to each account.
--
-- Usage:
/*
	USE AD419
	GO

	EXEC usp_UpdateNewAccountSFN
	GO
*/
--
-- Modifications:
--	20160818 by kjt: Revised to use the correct project table.
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateNewAccountSFN] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Update the Account and OP Fund Award Numbers:
	UPDATE [dbo].[NewAccountSFN]
	SET Accounts_AwardNum = t2.Accounts_AwardNum, OpFund_AwardNum = t2.OpFund_AwardNum
	FROM  [dbo].[NewAccountSFN] t1
	INNER JOIN 
	(select distinct Accounts.Chart, Account, Accounts.AwardNum Accounts_AwardNum, OPFund.AwardNum OpFund_AwardNum
	FROM
		FISDatamart.dbo.Accounts
	INNER JOIN 
		FISDatamart.dbo.OPFund ON Accounts.Chart = OPFund.Chart AND Accounts.OpFundNum = OPFund.FundNum AND Accounts.Year = OpFund.Year AND Accounts.Period = OPFund.Period
	WHERE Accounts.Year = 9999 AND Accounts.Period = '--') t2 ON t1.Account = t2.Account AND t1.Chart = t2.Chart

	-- Correct any irregular delimiters within the CFDA numbers:
    UPDATE NewAccountSFN SET CFDANum = REPLACE(CFDANum, '-','.') WHERE CFDANum IS NOT NULL

	-- Set any of the SFN for any of the accounts we've already identified as 204:
	UPDATE NewAccountSFN SET SFN = '204'
	FROM NewAccountSFN t1
	INNER JOIN [dbo].[AllAccountsFor204Projects] t2
	ON t1.chart = t2.Chart AND t1.Account = t2.Account
	
	-- Set any of the SFNs for NON 204 project accounts or 204 accounts that we not previously classfied
	-- because they are for 204 accounts that do not belong to projects that were in our college:
	UPDATE NewAccountSFN
	SET SFN =
		CASE  
			WHEN left(OpFundNum,5) in ('21005','21006','21009','21010') THEN '201'
			WHEN left(OpFundNum,5) in ('21013','21014','21015','21016') THEN '202'
			WHEN left(OpFundNum,5) in ('21007','21008') THEN '203'
			WHEN left(OpFundNum,5) in ('21003','21004') THEN '205'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='16' THEN '209'
			
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='11' THEN '308'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='05' THEN '310'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='03' THEN '311'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='06' and (left(NIHDocNum,2)<>'08' or NIHDocNum IS NULL) THEN '313'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='14' THEN '314'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='06' and left(NIHDocNum,2)='08' THEN '316'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') AND  (FederalAgencyCode = '01') and (SponsorCode = '0300') THEN '318'
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') AND  (FederalAgencyCode NOT IN ('01','03','05','06','11','14','16') OR FederalAgencyCode IS NULL) THEN '318'
	
			WHEN (OpFundGroupCode LIKE '401%') OR (OpFundGroupCode LIKE '404%' AND (NOT SponsorCategoryCode LIKE '12' OR SponsorCategoryCode IS NULL)) THEN '220'
			WHEN left(OpFundGroupCode,3) in ('409') THEN '221'

			WHEN OpFundGroupCode LIKE '4%' AND left(OpFundGroupCode,3) in ('402','403','410','411') THEN '223C'
			WHEN left(OpFundGroupCode,3) in ('408') and (SponsorCategoryCode not in ('05','12') OR SponsorCategoryCode IS NULL) THEN '222A' --Gifts
			WHEN OpFundGroupCode like '405%' THEN '223A' 
			WHEN OpFundGroupCode LIKE '407%' THEN '222B' --Endowments
			WHEN (OpFundGroupCode LIKE '4042%' and SponsorCategoryCode LIKE '12') OR (OpFundGroupCode LIKE '408%' and SponsorCategoryCode in ('05','12')) THEN '222C' --Commodities
			
			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='01' and SponsorCode in ('0450','0334') 
				AND  left(OpFundNum,5) not in ('21003','21004','21005','21006','21007','21008','21009','21010', '21013','21014','21015','21016')
				AND (CFDANum IN (SELECT CFDANum FROM [AD419].[dbo].[CFDANumImport]) OR
					RIGHT(RTRIM(t3.ProjectNumber),2) IN ('CG','OG','SG'))	THEN '204'

			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='01' and SponsorCode in ('0599') 
				AND  left(OpFundNum,5) not in ('21003','21004','21005','21006','21007','21008','21009','21010', '21013','21014','21015','21016')
				AND CFDANum IN ('10.309','10.310') AND (LEFT(Accounts_AwardNum, 2) NOT BETWEEN '50' AND '89' ) AND (LEFT(OpFund_AwardNum, 2) NOT BETWEEN '50' AND '99' )
				THEN '204'

			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='01' and  
			(SponsorCode NOT IN ('0300','0450','0334') OR SponsorCode IS NULL) THEN '219' 

			WHEN left(OpFundGroupCode,4) in ('4061','4062','4063') and FederalAgencyCode='01' and  (SponsorCode IN ('0450')) 
				THEN '219' 
			ELSE NULL
		END
		FROM NewAccountSFN t1
		LEFT OUTER JOIN [dbo].[AllProjectsNew] t3 ON 
			REPLACE(t1.[Accounts_AwardNum], '-','') = REPLACE(t3.AwardNumber, '-','') OR 
			REPLACE([OPFund_AwardNum], '-','')  = REPLACE(t3.AwardNumber, '-','')
		WHERE t1.SFN IS NULL OR t1.SFN <> '204'

		-- Clear the IsAccountInFinancialData flag
		update [AD419].[dbo].NewAccountSFN
		set [IsAccountInFinancialData] = 0

		-- Make sure that [FFY_ExpensesByARC] is loaded first!
		-- Set the IsAccountInFinancialData flag:
		update [AD419].[dbo].NewAccountSFN
		set [IsAccountInFinancialData] = 1
		from [AD419].[dbo].NewAccountSFN t1
		INNER JOIN [dbo].[FFY_ExpensesByARC] t2 ON t1.chart = t2.chart and t1.account = t2.account
END