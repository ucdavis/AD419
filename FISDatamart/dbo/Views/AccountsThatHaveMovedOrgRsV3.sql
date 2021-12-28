CREATE VIEW [dbo].[AccountsThatHaveMovedOrgRsV3]
AS
SELECT TOP 100 Percent  t1.Year FormerYear,
t1.Chart, t1.Account, t1.Org FormerOrg, t2.Org CurrentOrg, t1.OrgR FormerOrgR, t3.OrgR CurrentOrgR--, t1.Period FormerPeriod 
FROM (
SELECT row_number() OVER (PARTITION BY t1.Chart, t1.Account, t1.Org, t2.OrgR ORDER BY t1.Year DESC, t1.Period DESC) RowNum,
t1.Chart, t1.Account, t1.Org, t2.OrgR, t1.Year, t1.Period
FROM Accounts t1
INNER JOIN OrganizationsV t2 On t1.Chart = t2.Chart and t1.Org = t2.Org and t1.Year = t2.year and t1.Period = t2.Period

WHERE 
--t1.chart = '3' and t1.account IN ('DAM2332', '2200349', 'VMW2006' ) and
 not exists (
	select t3.chart, orgR, account 
	from accounts t3
	LEFT OUTER JOIN OrganizationsV t4 ON t3.Chart = t4.Chart AND t3.Org = t4.Org AND t3.Year = t4.Year and t3.Period = t4.Period
	WHERE t3.Year = 9999 and t3.Period = '--' and t1.Chart = t3.Chart and t1.Account = t3.Account and t4.OrgR = t2.OrgR
)
--AND t1.Chart = '3' and t1.Account IN ('2200349','DAM2332','VMW2006')
) t1
LEFT OUTER JOIN Accounts t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account AND t2.Period = '--' AND t2.Year = 9999
LEFT OUTER JOIN OrganizationsV t3 ON t2.Chart = t3.Chart AND t2.Org = t3.Org AND t2.Year = t3.Year AND t2.Period = t3.Period
WHERE RowNum = 1
ORDER BY t1.Chart, t1.Account, t1.Org, t1.OrgR --, t1.Year desc, t1.Period desc
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsThatHaveMovedOrgRsV3';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsThatHaveMovedOrgRsV3';

