CREATE VIEW dbo.FFY_ExpensesByARCWithSFN
AS
SELECT        t1.AnnualReportCode, t1.Chart, t1.Account, t1.ConsolidationCode, t1.DirectTotal, t1.IndirectTotal, t1.Total, t2.SFN
FROM            dbo.FFY_ExpensesByARC AS t1 LEFT OUTER JOIN
                         dbo.NewAccountSFN AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
WHERE        ((t1.Chart + t1.Account) NOT IN
                             (SELECT        Chart + Account AS Expr1
                               FROM            dbo.ARCCodeAccountExclusionsV))