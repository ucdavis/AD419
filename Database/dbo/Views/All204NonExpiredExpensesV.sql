CREATE VIEW dbo.All204NonExpiredExpensesV
AS
SELECT DISTINCT t1.[Chart], t1.[Account], t1.SubAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t2.[OrgR], t1.[Org], t1.[Expenses]
FROM            UFY_FFY_FIS_Expenses t1 INNER JOIN
                         AllAccountsFor204Projects t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
WHERE        IsExpired = 0 AND IsUCD = 1
GROUP BY t1.Chart, t1.Account, t1.subAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t2.[OrgR], t1.[Org], t1.[Expenses]
UNION
SELECT        t1.[Chart], t1.[Account], t1.SubAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t1.[OrgR] OrgR, t1.[Org], t1.Expenses
FROM            [AD419].[dbo].[Missing204AccountExpenses] t1
WHERE        IsExpired = 0 AND IsUCD = 1
GROUP BY t1.[Chart], t1.[Account], t1.SubAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t1.[OrgR], t1.[Org], t1.Expenses
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'All204NonExpiredExpensesV';


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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'All204NonExpiredExpensesV';

