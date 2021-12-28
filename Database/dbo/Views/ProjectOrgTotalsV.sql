CREATE VIEW dbo.ProjectOrgTotalsV
AS
SELECT        TOP (100000) t3.Project, t2.Accession, t1.OrgR, t1.Org, COALESCE (t4.Name, t5.Name) AS OrgName, t3.inv1, t1.PI_Name, SUM(t2.Expenses) 
                         AS TotalExpensesForOrgProject, SUM(t2.FTE) AS TotalFteForOrgForProject
FROM            dbo.Expenses AS t1 INNER JOIN
                         dbo.Associations AS t2 ON t1.ExpenseID = t2.ExpenseID INNER JOIN
                         dbo.Project AS t3 ON t2.Accession = t3.Accession LEFT OUTER JOIN
                         FISDataMart.dbo.Organizations AS t4 ON t1.Org = t4.Org AND t4.Chart = '3' AND t4.Year = 9999 AND t4.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Organizations AS t5 ON t1.Org = t5.Org AND t5.Chart = 'L' AND t5.Year = 9999 AND t5.Period = '--'
WHERE        (t3.Is204 IS NULL) OR
                         (t3.Is204 = 0)
GROUP BY t3.Project, t2.Accession, t1.OrgR, t1.Org, COALESCE (t4.Name, t5.Name), t3.inv1, t1.PI_Name
ORDER BY t3.Project, t2.Accession, t1.OrgR, t1.Org, OrgName, t3.inv1, t1.PI_Name
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ProjectOrgTotalsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'e = 1170
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ProjectOrgTotalsV';


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
         Begin Table = "t1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 236
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2"
            Begin Extent = 
               Top = 6
               Left = 274
               Bottom = 135
               Right = 460
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t3"
            Begin Extent = 
               Top = 6
               Left = 498
               Bottom = 135
               Right = 709
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t4"
            Begin Extent = 
               Top = 6
               Left = 747
               Bottom = 135
               Right = 942
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t5"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 267
               Right = 233
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
      Begin ColumnWidths = 10
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 12
         Column = 1440
         Alias = 900
         Tabl', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ProjectOrgTotalsV';

