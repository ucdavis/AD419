CREATE VIEW dbo.UFY_FFY_FIS_ExpensesWithSFN
AS
SELECT        t1.Id, t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.AnnualReportCode, t1.OpFundNum, t1.ConsolidationCode, t1.TransDocType, t1.OrgR, t1.Org, 
                         t1.Expenses, t2.SFN
FROM            dbo.UFY_FFY_FIS_Expenses AS t1 LEFT OUTER JOIN
                         dbo.NewAccountSFN AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account