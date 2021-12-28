CREATE VIEW [dbo].[PurchasingOrgsV]
AS
SELECT     TOP (100) PERCENT Chart + '-' + Org AS Org, Name, 
                      CASE WHEN org = org8 THEN chart7 + '-' + org7 WHEN org = org7 THEN chart6 + '-' + org6 WHEN org = org6 THEN chart5 + '-' + org5 WHEN org = org5 THEN chart4 + '-'
                       + org4 WHEN org = org4 THEN chart3 + '-' + org3 WHEN org = org3 THEN chart2 + '-' + org2 WHEN org = org2 THEN chart1 + '-' + org1 WHEN org = org1 THEN NULL 
                      END AS Parent
FROM         dbo.OrganizationsV
WHERE     (Year = 9999)
ORDER BY Org, Name
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'PurchasingOrgsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'PurchasingOrgsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'View for use with purchasing app.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'PurchasingOrgsV';

