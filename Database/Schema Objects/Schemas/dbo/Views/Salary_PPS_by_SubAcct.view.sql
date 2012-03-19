CREATE VIEW [dbo].[Salary_PPS_by_SubAcct]
AS
SELECT     TOP 100 PERCENT Org_R, Account, SubAcct, ObjConsol, SUM(Expenses) AS Expenses
FROM         dbo.Expenses_PPS
GROUP BY Org_R, Account, SubAcct, ObjConsol
ORDER BY Org_R, Account, SubAcct, ObjConsol
