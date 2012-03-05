CREATE VIEW [dbo].[Expenses_Salary_Reversals]
AS
SELECT     TOP (100) PERCENT dbo.Salary_FIS_by_SubAcct.Org_R, dbo.Salary_PPS_by_SubAcct.Org_R AS PPS_Org, dbo.Salary_FIS_by_SubAcct.Account, 
                      dbo.Salary_FIS_by_SubAcct.SubAccount, dbo.Salary_FIS_by_SubAcct.ObjConsol, dbo.Salary_FIS_by_SubAcct.FIS_Salary, 
                      dbo.Salary_PPS_by_SubAcct.Expenses AS PPS_Expenses, dbo.Salary_PPS_by_SubAcct.Expenses - dbo.Salary_FIS_by_SubAcct.FIS_Salary AS SalDiff, 
                      ROUND(dbo.udf_Reversal_Calc(dbo.Salary_FIS_by_SubAcct.FIS_Salary, dbo.Salary_PPS_by_SubAcct.Expenses), 2) AS ReversalAmt
FROM         dbo.Salary_FIS_by_SubAcct LEFT OUTER JOIN
                      dbo.Salary_PPS_by_SubAcct ON dbo.Salary_FIS_by_SubAcct.ObjConsol = dbo.Salary_PPS_by_SubAcct.ObjConsol AND 
                      dbo.Salary_FIS_by_SubAcct.SubAccount = dbo.Salary_PPS_by_SubAcct.SubAcct AND 
                      dbo.Salary_FIS_by_SubAcct.Account = dbo.Salary_PPS_by_SubAcct.Account
GROUP BY dbo.Salary_FIS_by_SubAcct.Org_R, dbo.Salary_PPS_by_SubAcct.Org_R, dbo.Salary_FIS_by_SubAcct.Account, dbo.Salary_FIS_by_SubAcct.SubAccount, 
                      dbo.Salary_FIS_by_SubAcct.ObjConsol, dbo.Salary_FIS_by_SubAcct.FIS_Salary, ROUND(dbo.udf_Reversal_Calc(dbo.Salary_FIS_by_SubAcct.FIS_Salary, 
                      dbo.Salary_PPS_by_SubAcct.Expenses), 2), dbo.Salary_PPS_by_SubAcct.Expenses, 
                      dbo.Salary_PPS_by_SubAcct.Expenses - dbo.Salary_FIS_by_SubAcct.FIS_Salary
HAVING      (dbo.Salary_FIS_by_SubAcct.FIS_Salary <> 0)
ORDER BY dbo.Salary_FIS_by_SubAcct.Org_R, dbo.Salary_FIS_by_SubAcct.Account, dbo.Salary_FIS_by_SubAcct.SubAccount, dbo.Salary_FIS_by_SubAcct.ObjConsol

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
         Begin Table = "Salary_FIS_by_SubAcct"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 123
               Right = 214
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Salary_PPS_by_SubAcct"
            Begin Extent = 
               Top = 6
               Left = 252
               Bottom = 123
               Right = 428
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
End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Expenses_Salary_Reversals';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Expenses_Salary_Reversals';

