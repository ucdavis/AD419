CREATE VIEW dbo.FFY_SFN_EntriesV
AS
SELECT        t1.Id, t1.Chart, t1.Account, t1.SFN, t1.Accounts_AwardNum, t1.OpFund_AwardNum, t1.AccessionNumber, t1.ProjectNumber, t1.Expenses, t1.FTE, t1.IsExpired, 
                         t1.ProjectEndDate, t2.PrincipalInvestigatorName, t2.Purpose, t2.AccountName
FROM            dbo.FFY_SFN_Entries AS t1 LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.Year = 9999 AND t2.Period = '--'
WHERE        ((t1.Chart + t1.Account) NOT IN
                             (SELECT        Chart + Account AS Expr1
                               FROM            dbo.ARCCodeAccountExclusionsV)) AND (t1.SFN NOT LIKE '204') OR
                         ((t1.Chart + t1.Account) NOT IN
                             (SELECT        Chart + Account AS Expr1
                               FROM            dbo.ARCCodeAccountExclusionsV AS ARCCodeAccountExclusionsV_1)) AND (t1.SFN LIKE '204') AND (t1.IsExpired = 0)