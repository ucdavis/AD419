CREATE VIEW dbo.AccessionOrgAssociationsV
AS
SELECT        TOP (100000) PctExp, PctFTE, CASE WHEN PctExp > (ProjectProratePercentage * 3) THEN 1 ELSE 0 END AS ExpFlag, 
                         CASE WHEN PctFTE > (ProjectProratePercentage * 3) THEN 1 ELSE 0 END AS FteFlag, Project, Accession, OrgR, Org, OrgName, inv1, PI_Name, 
                         TotalExpensesForOrgProject, TotalFteForOrgForProject, ProjectProratePercentage, TotalExpensesForOrgForAllProjects, TotalFteForOrgForAllProjects
FROM            (SELECT        CASE WHEN TotalExpensesForOrgForAllProjects != 0 THEN (TotalExpensesForOrgProject / TotalExpensesForOrgForAllProjects) ELSE NULL 
                                                    END AS PctExp, CASE WHEN TotalFteForOrgForAllProjects != 0 THEN (TotalFteForOrgForProject / TotalFteForOrgForAllProjects) ELSE 0 END AS PctFTE, 
                                                    t2.Project, t2.Accession, t2.OrgR, t2.Org, t2.OrgName, t2.inv1, t2.PI_Name, t2.TotalExpensesForOrgProject, t2.TotalFteForOrgForProject, 
                                                    t3.ProjectProratePercentage / 100 AS ProjectProratePercentage, t1.TotalExpensesForOrgForAllProjects, t1.TotalFteForOrgForAllProjects
                          FROM            dbo.OrgTotalsV AS t1 INNER JOIN
                                                    dbo.ProjectOrgTotalsV AS t2 ON t1.Org = t2.Org INNER JOIN
                                                    dbo.OrgRProjectProratePercentV AS t3 ON t2.OrgR = t3.OrgR) AS t1_1
ORDER BY ExpFlag DESC, FteFlag DESC, PctExp DESC, PctFTE DESC, Accession
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccessionOrgAssociationsV';


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
         Begin Table = "t1_1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 311
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
      Begin ColumnWidths = 17
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
      Begin ColumnWidths = 11
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccessionOrgAssociationsV';

