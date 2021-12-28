﻿
CREATE VIEW [dbo].[204AcctXProjV]
AS
SELECT        t1.Account AS AccountID, t1.Expenses AS Expenses, t1.Expenses AS DividedAmount, SUM(t1.FTE) AS FTE, t1.AccessionNumber AS Accession, 
                         t1.ProjectNumber, t1.Chart, NULL AS Is219, t1.AwardNumber AS CSREES_ContractNo, COALESCE (t2.OpFund_AwardNum, t2.Accounts_AwardNum) AS AwardNum, 
                         t1.ProjectEndDate, 1 ^ t1.IsExpired AS IsCurrentProject, t1.Org, t1.OrgR, CASE WHEN ExcludedByAccount = 1 OR
                         IsUCD = 0 THEN 1 ELSE 0 END AS IsExcludedExpense, t1.OpFundNum
FROM            dbo.AllAccountsFor204Projects AS t1 INNER JOIN
                         dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.SFN = '204'
GROUP BY t1.Chart, t1.Account, t1.AccessionNumber, t1.ProjectNumber, t1.AwardNumber, COALESCE (t2.OpFund_AwardNum, t2.Accounts_AwardNum), t1.OrgR, t1.Org, 
                         t1.ProjectEndDate, t1.IsExpired, CASE WHEN ExcludedByAccount = 1 OR
                         IsUCD = 0 THEN 1 ELSE 0 END, t1.OpFundNum, t1.Expenses
HAVING        (SUM(t1.Expenses) <> 0) AND (SUM(t1.Expenses) IS NOT NULL)
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'204AcctXProjV';


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
               Right = 277
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2"
            Begin Extent = 
               Top = 6
               Left = 315
               Bottom = 135
               Right = 536
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
      Begin ColumnWidths = 16
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'204AcctXProjV';

