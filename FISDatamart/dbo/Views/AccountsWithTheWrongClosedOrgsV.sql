CREATE VIEW [dbo].[AccountsWithTheWrongClosedOrgsV]
AS
SELECT TOP 100 PERCENT
	t1.Chart, t1.Account, 
	ClosedOrg CurrentOrg, 
	NonClosedOrg LatestNonClosedOrg, 
	t3.OrgR CurrentOrgR, 
	t2.OrgR LatestNonClosedOrgR, 
	Max(t1.Year) AS LatestNonClosedYear, Max(t1.Period) AS LatestNonClosedPeriod
  FROM (
	  SELECT DISTINCT 
		ROW_NUMBER() OVER (PARTITION BY t1.Chart, t1.Account ORDER BY t3.Year DESC, t3.Period Desc) AS RowNum, 
		t3.Org NonClosedOrg, t1.Org ClosedOrg, 
		t1.Chart, t1.Account, 
		Max(t3.Year) Year, MaX(t3.Period) Period 
	  FROM Accounts t1 
	  INNER JOIN (
		SELECT ca.Chart, ca.Org
		FROM [dbo].[ClosedOrgsV] ca
	  ) t2 ON t2.Chart = t1.Chart AND t2.Org = t1.Org
	  LEFT OUTER JOIN Accounts t3 ON t1.Chart = t3.Chart AND t1.Account = t3.Account
		AND t3.Org NOT IN (SELECT Org FROM [dbo].[ClosedOrgsV])
	  WHERE t1.Year = 9999 and t1.Period = '--' AND t3.Org IS NOT NULL
	  GROUP BY t3.Org, t1.Org, t1.Chart, t1.Account, t3.Year, t3.Period
  ) t1
  LEFT OUTER JOIN OrganizationsV t2 ON 
	t1.Chart = t2.Chart AND t1.NonClosedOrg = t2.Org AND 
	t2.Year = 9999 AND t2.Period = '--'
  LEFT OUTER JOIN OrganizationsV t3 ON 
	t1.Chart = t3.Chart AND t1.ClosedOrg = t3.Org AND 
	t3.Year = 9999 AND t3.Period = '--'
  WHERE RowNum = 1
  GROUP BY  NonClosedOrg, t2.OrgR, ClosedOrg, t3.OrgR, t1.Chart, Account
  HAVING t2.OrgR  != t3.OrgR AND NonClosedOrg NOT IN ('BIOS') AND t3.OrgR NOT LIKE 'B%'
  ORDER by t1.Chart, Account
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsWithTheWrongClosedOrgsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsWithTheWrongClosedOrgsV';

