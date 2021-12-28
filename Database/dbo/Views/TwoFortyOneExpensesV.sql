
CREATE VIEW [dbo].[TwoFortyOneExpensesV]
AS
SELECT        TOP (100) PERCENT ExpenseID, Employee_Name, EID, OrgR, Expenses, FTE, isAssociated
FROM            (SELECT        OrgR, Expenses, FTE, EID, ExpenseID, isAssociated, Employee_Name
                          FROM            dbo.Expenses AS t1
                          WHERE        (FTE_SFN = '241')
                          UNION
                          SELECT        t1.OrgR, t1.Expenses, t1.FTE, t1.EID, t1.ExpenseID, t1.isAssociated, t1.Employee_Name
                          FROM            dbo.Expenses AS t1 INNER JOIN
                                                   dbo.ProjectPI AS t4 ON t1.EID = t4.EmployeeID
                          WHERE        (t1.FTE_SFN = '242')
                          UNION
                          SELECT        t1.OrgR, t1.Expenses, t1.FTE, t1.EID, t1.ExpenseID, t1.isAssociated, t1.Employee_Name
                          FROM            dbo.Expenses AS t1 INNER JOIN
                                                   PPSDataMart.dbo.TitleCodesSelfCertify AS t4 ON t1.TitleCd = t4.TitleCode INNER JOIN
                                                   dbo.ProjectPI AS t5 ON t1.EID = t5.EmployeeID
                          WHERE        (t1.FTE_SFN NOT IN ('241', '242'))) AS t1_1
WHERE        (OrgR NOT IN
                             (SELECT        OrgR
                               FROM            dbo.udf_GetOrgRExclusions() AS udf_GetOrgRExclusions_1))
GROUP BY OrgR, EID, ExpenseID, Expenses, FTE, Employee_Name, isAssociated
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TwoFortyOneExpensesV';


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
               Bottom = 136
               Right = 232
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TwoFortyOneExpensesV';

