CREATE VIEW dbo.vDeptOrgMatchingForAccounts
AS
SELECT        t1.Chart, t1.Account, t1.Org AS [9999 Org], t5.Org AS [2018 Org], t6.Org AS [2018-04 Org], t4.Org AS [2017 Org], t7.OrgR AS ReportingOrg, COALESCE (t2.OrgR, t7.OrgR) AS OrgR
FROM            FISDataMart.dbo.Accounts AS t1 LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t4 ON t1.Chart = t4.Chart AND t1.Account = t4.Account AND t4.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 1 AS Expr1) AND t4.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t5 ON t1.Chart = t5.Chart AND t1.Account = t5.Account AND t5.Year =
                             (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND t5.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t6 ON t1.Chart = t6.Chart AND t1.Account = t6.Account AND t6.Year =
                             (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND t6.Period = '04' LEFT OUTER JOIN
                         dbo.ReportingOrg AS t7 ON t1.Org = t7.OrgR AND t7.IsActive = 1 LEFT OUTER JOIN
                         dbo.UFYOrganizationsOrgR_v AS t2 ON t1.Chart = t2.Chart AND t2.Org = CASE WHEN t1.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t1.Org WHEN t5.Org NOT IN ('DUMP', 'EXPR', 
                         'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t5.Org WHEN t6.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t6.Org WHEN t4.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 
                         'AAES', 'PDED') THEN t4.Org END
WHERE        (t1.Year = 9999) AND (t1.Period = '--') AND (t1.Chart = '3') AND (t1.Account IN ('AGARGAA', 'ARUSPAK', 'BTNYGRN', 'BTYSEND', 'CPRBGD2', 'CPRBJP3', 'CXN0474', 'EEOPGSR', 'GRNHSAL', 'HBSHATC', 'JADHATC', 
                         'JCC0453', 'LDG0127', 'MARVELR', 'MAWF298', 'MAWME01', 'MB56743', 'MCDFALR', 'MCSARCS', 'NPBHAJA', 'PLBESAU', 'RAVFLRD', 'RAVFNGS', 'RIABRB2', 'RM00787', 'RMFINAW', 'RMUSDAW', 'RUSFLSP', 
                         'SPL0317'))
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vDeptOrgMatchingForAccounts';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'       Output = 720
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vDeptOrgMatchingForAccounts';


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
               Bottom = 136
               Right = 267
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t4"
            Begin Extent = 
               Top = 6
               Left = 305
               Bottom = 136
               Right = 534
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t5"
            Begin Extent = 
               Top = 6
               Left = 572
               Bottom = 136
               Right = 801
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t6"
            Begin Extent = 
               Top = 6
               Left = 839
               Bottom = 136
               Right = 1068
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t7"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 323
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2"
            Begin Extent = 
               Top = 138
               Left = 361
               Bottom = 268
               Right = 531
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
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
  ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vDeptOrgMatchingForAccounts';

