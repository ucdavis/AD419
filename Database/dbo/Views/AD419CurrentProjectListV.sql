CREATE VIEW dbo.AD419CurrentProjectListV
AS
SELECT        ProjectNew.AccessionNumber, ProjectNew.ProjectNumber, ProjectNew.ProposalNumber, ProjectNew.AwardNumber, ProjectNew.Title, ProjectNew.OrganizationName, 
                         ProjectNew.OrgR, ProjectNew.Department, ProjectNew.ProjectDirector, ProjectNew.CoProjectDirectors, ProjectNew.FundingSource, ProjectNew.ProjectStartDate, 
                         ProjectNew.ProjectEndDate, ProjectNew.ProjectStatus, ProjectNew.IsInterdepartmental, CONVERT(bit, ISNULL(ProjectNew.IsIgnored ^ 1, 1)) AS IsAssociable
FROM            dbo.AllProjectsNew AS ProjectNew INNER JOIN
                         dbo.CurrentFiscalYear AS t2 ON ProjectNew.ProjectEndDate >= CONVERT(DateTime, CONVERT(varchar(4), t2.FiscalYear - 1) + '-03-01 00:00:00.000') AND 
                         ProjectNew.ProjectStartDate < CONVERT(DateTime, CONVERT(varchar(4), t2.FiscalYear) + '-10-01 00:00:00.000') LEFT OUTER JOIN
                         dbo.ReportingOrg AS t8 ON ProjectNew.OrgR = t8.OrgR AND (t8.IsActive = 1 OR
                         t8.OrgR IN ('XXXX', 'AINT'))
WHERE        (ProjectNew.IsUCD = 1) AND (ProjectNew.IsExpired = 0) AND (ProjectNew.AccessionNumber NOT LIKE '0000000') AND (RTRIM(ProjectNew.ProjectStatus) 
                         NOT IN
                             (SELECT        Status
                               FROM            dbo.ProjectStatus
                               WHERE        (IsExcluded = 1)))
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AD419CurrentProjectListV';


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
         Begin Table = "ProjectNew"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 230
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2"
            Begin Extent = 
               Top = 6
               Left = 268
               Bottom = 84
               Right = 438
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t8"
            Begin Extent = 
               Top = 6
               Left = 476
               Bottom = 135
               Right = 761
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
      Begin ColumnWidths = 9
         Width = 284
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AD419CurrentProjectListV';

