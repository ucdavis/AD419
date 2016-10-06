CREATE VIEW dbo.New204Test
AS
SELECT        t1.Chart, t1.Account, ISNULL(t1.Expenses, 0) AS SumOfExpenseSum, t1.AccessionNumber AS Accession, t2.Accounts_AwardNum, t2.OpFund_AwardNum, 
                         t1.IsExpired ^ 1 AS IsCurrentProject, t1.OrgR, t1.Org, t3.CFDANum, t3.OpFundGroupCode, t3.FederalAgencyCode, t3.NIHDocNum, t3.SponsorCode, 
                         t3.SponsorCategoryCode, t3.OpFundNum, t2.AccountName, t2.Purpose, t6.FundName, t4.Title AS ProjectTitle, t1.SFN AS ExpSFN, CASE WHEN t5.Account IS NULL 
                         THEN 0 ELSE 1 END AS IsManuallyExcluded
FROM            dbo.AllAccountsFor204Projects AS t1 LEFT OUTER JOIN
                         dbo.FFY_SFN_EntriesV AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account LEFT OUTER JOIN
                         dbo.NewAccountSFN AS t3 ON t1.Chart = t3.Chart AND t1.Account = t3.Account LEFT OUTER JOIN
                         dbo.AllProjectsNew AS t4 ON t1.AccessionNumber = t4.AccessionNumber LEFT OUTER JOIN
                         dbo.ArcCodeAccountExclusions AS t5 ON t1.Chart = t5.Chart AND t1.Account = t5.Account LEFT OUTER JOIN
                         FISDataMart.dbo.OPFund AS t6 ON t3.OpFundNum = t6.FundNum AND t1.Chart = t6.Chart AND t6.Year = 9999 AND t6.Period = '--'
GROUP BY t1.Chart, t1.Account, t1.AccessionNumber, ISNULL(t1.Expenses, 0), t2.Accounts_AwardNum, t2.OpFund_AwardNum, t1.IsExpired ^ 1, t1.OrgR, t1.Org, t3.CFDANum, 
                         t3.OpFundGroupCode, t3.FederalAgencyCode, t3.NIHDocNum, t3.SponsorCode, t3.SponsorCategoryCode, t3.OpFundNum, t2.AccountName, t2.Purpose, t6.FundName, 
                         t4.Title, t1.SFN, CASE WHEN t5.Account IS NULL THEN 0 ELSE 1 END