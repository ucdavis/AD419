CREATE VIEW dbo.New204Test
AS
SELECT        t1.Chart, t1.Account, ISNULL(t1.Expenses, 0) AS SumOfExpenseSum, t1.AccessionNumber AS Accession, t2.Accounts_AwardNum, t2.OpFund_AwardNum, 
                         t1.IsExpired ^ 1 AS IsCurrentProject, t1.OrgR, t1.Org, t3.CFDANum, t3.OpFundGroupCode, t3.FederalAgencyCode, t3.NIHDocNum, t3.SponsorCode, 
                         t3.SponsorCategoryCode, t3.OpFundNum, t2.AccountName, t2.Purpose, t6.FundName, t4.Title AS ProjectTitle, t1.SFN AS ExpSFN, CASE WHEN t5.Account IS NULL 
                         THEN 0 ELSE 1 END AS IsManuallyExcluded
FROM            dbo.AllAccountsFor204Projects AS t1 LEFT OUTER JOIN
                         dbo.FFY_SFN_EntriesV AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account LEFT OUTER JOIN
                         dbo.NewAccountSFN AS t3 ON t1.Chart = t3.Chart AND t1.Account = t3.Account LEFT OUTER JOIN
                         dbo.AllProjectsNew AS t4 ON t1.AccessionNumber = t4.AccessionNumber LEFT OUTER JOIN
                         dbo.ArcCodeAccountExclusions AS t5 ON t1.Chart = t5.Chart AND t1.Account = t5.Account LEFT OUTER JOIN
                         [$(FISDataMart)].dbo.OPFund AS t6 ON t3.OpFundNum = t6.FundNum AND t1.Chart = t6.Chart AND t6.Year = 9999 AND t6.Period = '--'
GROUP BY t1.Chart, t1.Account, t1.AccessionNumber, ISNULL(t1.Expenses, 0), t2.Accounts_AwardNum, t2.OpFund_AwardNum, t1.IsExpired ^ 1, t1.OrgR, t1.Org, t3.CFDANum, 
                         t3.OpFundGroupCode, t3.FederalAgencyCode, t3.NIHDocNum, t3.SponsorCode, t3.SponsorCategoryCode, t3.OpFundNum, t2.AccountName, t2.Purpose, t6.FundName, 
                         t4.Title, t1.SFN, CASE WHEN t5.Account IS NULL THEN 0 ELSE 1 END
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'New204Test';


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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'New204Test';


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
               Right = 560
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t3"
            Begin Extent = 
               Top = 6
               Left = 598
               Bottom = 135
               Right = 837
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t4"
            Begin Extent = 
               Top = 6
               Left = 875
               Bottom = 135
               Right = 1083
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t5"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 267
               Right = 244
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t6"
            Begin Extent = 
               Top = 138
               Left = 282
               Bottom = 267
               Right = 494
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
  ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'New204Test';

