CREATE VIEW dbo.[Non241PI_EmployeesV]
AS
SELECT        dbo.Expenses.Employee_Name, dbo.Expenses.EID, dbo.Expenses.TitleCd, CASE WHEN TitleCode IS NOT NULL THEN 1 ELSE 0 END AS IsCond241, 
                         CASE WHEN COUNT(Accession) > 0 THEN 1 ELSE 0 END AS IsProjectPI, dbo.Expenses.Title_Code_Name, dbo.Expenses.FTE_SFN, dbo.Expenses.OrgR
FROM            dbo.Expenses INNER JOIN
                             (SELECT DISTINCT PI_Name
                               FROM            dbo.Expenses AS Expenses_1) AS names ON dbo.Expenses.Employee_Name = names.PI_Name LEFT OUTER JOIN
                         PPSDataMart.dbo.TitleCodesSelfCertify AS TCSC ON dbo.Expenses.TitleCd = TCSC.TitleCode LEFT OUTER JOIN
                         dbo.PI_Match AS PIM ON dbo.Expenses.EID = PIM.EID
WHERE        (dbo.Expenses.FTE_SFN <> '241')
GROUP BY dbo.Expenses.Employee_Name, dbo.Expenses.EID, dbo.Expenses.OrgR, dbo.Expenses.TitleCd, TCSC.TitleCode, dbo.Expenses.Title_Code_Name, 
                         dbo.Expenses.FTE_SFN
HAVING        (SUM(dbo.Expenses.FTE) <> 0)
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Non241PI_EmployeesV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "Expenses"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 236
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "names"
            Begin Extent = 
               Top = 6
               Left = 274
               Bottom = 84
               Right = 460
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "TCSC"
            Begin Extent = 
               Top = 84
               Left = 274
               Bottom = 213
               Right = 468
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "PIM"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 267
               Right = 224
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 12
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Non241PI_EmployeesV';

