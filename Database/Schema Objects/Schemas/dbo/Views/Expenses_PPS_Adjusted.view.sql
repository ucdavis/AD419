CREATE VIEW [dbo].[Expenses_PPS_Adjusted]
AS
SELECT     TOP (100) PERCENT dbo.Expenses_Salary_Reversals.Org_R, dbo.Expenses_Salary_Reversals.Account, dbo.Expenses_Salary_Reversals.SubAccount, 
                      dbo.Expenses_Salary_Reversals.ObjConsol, dbo.Expenses_PPS.TOE_Name, dbo.Expenses_PPS.Employee_ID, dbo.Expenses_PPS.TitleCd, 
                      dbo.staff_type.Staff_Type_Short_Name AS staff_type, dbo.Expenses_Salary_Reversals.PPS_Expenses AS PPS_SubAcct_Total, 
                      dbo.Expenses_Salary_Reversals.FIS_Salary AS FIS_SubAcct_Total, dbo.Expenses_PPS.Expenses AS PPS_Expense, 
                      ROUND(dbo.Expenses_Salary_Reversals.ReversalAmt / dbo.Expenses_Salary_Reversals.PPS_Expenses * dbo.Expenses_PPS.Expenses, 2) AS Adjusted_Expense, 
                      dbo.staff_type.AD419_Line_Num AS fte_sfn, dbo.Expenses_PPS.FTE
FROM         dbo.staff_type RIGHT OUTER JOIN
                      PPSDataMart.dbo.Titles ON dbo.staff_type.Staff_Type_Code = PPSDataMart.dbo.Titles.StaffType RIGHT OUTER JOIN
                      dbo.Expenses_Salary_Reversals INNER JOIN
                      dbo.Expenses_PPS ON dbo.Expenses_Salary_Reversals.Account = dbo.Expenses_PPS.Account AND 
                      dbo.Expenses_Salary_Reversals.SubAccount = dbo.Expenses_PPS.SubAcct AND dbo.Expenses_Salary_Reversals.ObjConsol = dbo.Expenses_PPS.ObjConsol ON 
                      PPSDataMart.dbo.Titles.TitleCode = dbo.Expenses_PPS.TitleCd
WHERE     (dbo.Expenses_Salary_Reversals.ReversalAmt <> 0) AND (dbo.Expenses_PPS.Expenses <> 0)
ORDER BY dbo.Expenses_Salary_Reversals.Org_R, dbo.Expenses_PPS.TOE_Name, dbo.Expenses_Salary_Reversals.Account, dbo.Expenses_Salary_Reversals.SubAccount, 
                      dbo.Expenses_Salary_Reversals.ObjConsol

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
         Begin Table = "staff_type"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 123
               Right = 246
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Titles (PPSDataMart.dbo)"
            Begin Extent = 
               Top = 6
               Left = 284
               Bottom = 123
               Right = 492
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Expenses_Salary_Reversals"
            Begin Extent = 
               Top = 6
               Left = 530
               Bottom = 123
               Right = 690
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Expenses_PPS"
            Begin Extent = 
               Top = 6
               Left = 728
               Bottom = 123
               Right = 895
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Expenses_PPS_Adjusted';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Expenses_PPS_Adjusted';

