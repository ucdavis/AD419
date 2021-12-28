CREATE VIEW dbo.KensNewestOrgLogic
AS
SELECT DISTINCT 
                         TOP (100) PERCENT t2018.Chart, t2018.Account, CASE WHEN t2018.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t2018.Org WHEN t201807.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t201807.Org WHEN t201804.Org NOT IN ('DUMP', 
                         'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t201804.Org WHEN t9999.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t9999.Org WHEN t2017.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2017.Org WHEN t2016.Org NOT IN ('DUMP', 'EXPR', 
                         'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2016.Org WHEN t2015.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t2015.Org WHEN t2014.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2014.Org WHEN t2013.Org NOT IN ('DUMP', 'EXPR', 
                         'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2013.Org WHEN t2012.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t2012.Org WHEN t2011.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2011.Org END AS Org, COALESCE (t2.OrgR, t7.OrgR) 
                         AS OrgR
FROM            FISDataMart.dbo.Accounts AS t2018 LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2017 ON t2018.Chart = t2017.Chart AND t2018.Account = t2017.Account AND t2017.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 1 AS Expr1) AND t2017.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t201804 ON t2018.Chart = t201804.Chart AND t2018.Account = t201804.Account AND t201804.Year =
                             (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND t201804.Period = '04' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2011 ON t2018.Chart = t2011.Chart AND t2018.Account = t2011.Account AND t2011.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 7 AS Expr1) AND t2011.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2012 ON t2018.Chart = t2012.Chart AND t2018.Account = t2012.Account AND t2012.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 6 AS Expr1) AND t2012.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2013 ON t2018.Chart = t2013.Chart AND t2018.Account = t2013.Account AND t2013.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 5 AS Expr1) AND t2013.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2014 ON t2018.Chart = t2014.Chart AND t2018.Account = t2014.Account AND t2014.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 4 AS Expr1) AND t2014.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2015 ON t2018.Chart = t2015.Chart AND t2018.Account = t2015.Account AND t2015.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 3 AS Expr1) AND t2015.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t2016 ON t2018.Chart = t2016.Chart AND t2018.Account = t2016.Account AND t2016.Year =
                             (SELECT        dbo.udf_GetFiscalYear() - 2 AS Expr1) AND t2016.Period = '--' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t201807 ON t2018.Chart = t201807.Chart AND t2018.Account = t201807.Account AND t201807.Year =
                             (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND t201807.Period = '07' LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts AS t9999 ON t2018.Chart = t9999.Chart AND t2018.Account = t9999.Account AND t9999.Year =
                             (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND t9999.Period = '--' LEFT OUTER JOIN
                         dbo.ReportingOrg AS t7 ON t2018.Org = t7.OrgR AND t7.IsActive = 1 LEFT OUTER JOIN
                         dbo.UFYOrganizationsOrgR_v AS t2 ON t2018.Chart = t2.Chart AND t2.Org = CASE WHEN t2018.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t2018.Org WHEN t201807.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t201807.Org WHEN t201804.Org NOT IN ('DUMP', 
                         'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t201804.Org WHEN t9999.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t9999.Org WHEN t2017.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2017.Org WHEN t2016.Org NOT IN ('DUMP', 'EXPR', 
                         'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2016.Org WHEN t2015.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t2015.Org WHEN t2014.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2014.Org WHEN t2013.Org NOT IN ('DUMP', 'EXPR', 
                         'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2013.Org WHEN t2012.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') 
                         THEN t2012.Org WHEN t2011.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN t2011.Org END
WHERE        (t2018.Year = 9999) AND (t2018.Period = '--')
ORDER BY t2018.Chart, t2018.Account
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'KensNewestOrgLogic';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N' TopColumn = 0
         End
         Begin Table = "t2015"
            Begin Extent = 
               Top = 270
               Left = 604
               Bottom = 399
               Right = 849
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2016"
            Begin Extent = 
               Top = 402
               Left = 38
               Bottom = 531
               Right = 283
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t201807"
            Begin Extent = 
               Top = 402
               Left = 321
               Bottom = 531
               Right = 566
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t9999"
            Begin Extent = 
               Top = 402
               Left = 604
               Bottom = 531
               Right = 849
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t7"
            Begin Extent = 
               Top = 534
               Left = 38
               Bottom = 663
               Right = 339
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2"
            Begin Extent = 
               Top = 534
               Left = 377
               Bottom = 663
               Right = 563
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'KensNewestOrgLogic';


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
         Begin Table = "t2018"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 283
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2017"
            Begin Extent = 
               Top = 6
               Left = 572
               Bottom = 135
               Right = 817
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t201804"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 267
               Right = 283
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2011"
            Begin Extent = 
               Top = 138
               Left = 321
               Bottom = 267
               Right = 566
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2012"
            Begin Extent = 
               Top = 138
               Left = 604
               Bottom = 267
               Right = 849
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2013"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 399
               Right = 283
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2014"
            Begin Extent = 
               Top = 270
               Left = 321
               Bottom = 399
               Right = 566
            End
            DisplayFlags = 280
           ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'KensNewestOrgLogic';

