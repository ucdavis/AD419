CREATE VIEW [dbo].[AccountsThatHaveMovedOrgRsV2]
AS
SELECT t1.Year, t1.Period, t1.Chart, t1.Account, t1.Org FormerOrg, t1.OrgR FormerOrgR, t2.Org CurrentOrg, t3.OrgR CurrentOrgR
FROM (
SELECT  ROW_NUMBER() OVER (PARTITION BY t1.Chart, t1.Account ORDER BY t1.Year DESC, t1.Period Desc) AS RowNum,
 t1.Year,t1.Period, t1.Chart, t1.Account,  t1.Org, t2.OrgR
FROM Accounts t1
INNER JOIN OrganizationsV t2 ON t1.Chart = t2.Chart AND t1.Org = t2.Org
LEFT OUTER JOIN OrganizationsV t3 ON t2.Chart = t3.Chart AND t2.Org = t3.Org AND t3.Year = 9999 AND t3.Period = '--'
WHERE  NOT EXISTS ( 
		SELECT DISTINCT Chart, Org FROM Accounts a
		WHERE a.Year = 9999 AND a.Period = '--' AND 
		t1.Chart = a.Chart AND t1.Org = a.Org AND t1.Account = a.Account	
)

GROUP BY t1.Year, t1.Period, t1.Org, t2.OrgR, t3.OrgR,t1.Chart, t1.Account, t2.Org
HAVING t2.OrgR = t3.OrgR

) t1
LEFT OUTER JOIN Accounts t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.Year = 9999 AND t2.Period = '--'
LEFT OUTER JOIN OrganizationsV t3 ON t2.Chart = t3.Chart AND t2.Org = t3.Org AND t3.Year = 9999 AND t3.Period = '--'
WHERE RowNum = 1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsThatHaveMovedOrgRsV2';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsThatHaveMovedOrgRsV2';

