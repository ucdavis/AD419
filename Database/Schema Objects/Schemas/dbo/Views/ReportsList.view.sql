/* This will return all the values for the non-admin report*/
CREATE VIEW dbo.ReportsList
AS
SELECT     TOP (100) PERCENT loc, dept, proj, project, accession, PI,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Amt
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '201')) AS f201,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '202')) AS f202,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '203')) AS f203,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '204')) AS f204,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '205')) AS f205,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Amt
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '201') OR
                                                   (PList.accession = Accession) AND (SFN = '202') OR
                                                   (PList.accession = Accession) AND (SFN = '203') OR
                                                   (PList.accession = Accession) AND (SFN = '204') OR
                                                   (PList.accession = Accession) AND (SFN = '205')) AS f231,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '219')) AS f219,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '209')) AS f209,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '310')) AS f310,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '308')) AS f308,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '311')) AS f311,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '316')) AS f316,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '312')) AS f312,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '313')) AS f313,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '314')) AS f314,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '315')) AS f315,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '318')) AS f318,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '219') OR
                                                   (PList.accession = Accession) AND (SFN = '209') OR
                                                   (PList.accession = Accession) AND (SFN = '310') OR
                                                   (PList.accession = Accession) AND (SFN = '308') OR
                                                   (PList.accession = Accession) AND (SFN = '311') OR
                                                   (PList.accession = Accession) AND (SFN = '316') OR
                                                   (PList.accession = Accession) AND (SFN = '312') OR
                                                   (PList.accession = Accession) AND (SFN = '313') OR
                                                   (PList.accession = Accession) AND (SFN = '314') OR
                                                   (PList.accession = Accession) AND (SFN = '315') OR
                                                   (PList.accession = Accession) AND (SFN = '318')) AS f332,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '220')) AS f220,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '22F')) AS f22F,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '221')) AS f221,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '222')) AS f222,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '223')) AS f223,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '220') OR
                                                   (PList.accession = Accession) AND (SFN = '22F') OR
                                                   (PList.accession = Accession) AND (SFN = '221') OR
                                                   (PList.accession = Accession) AND (SFN = '222') OR
                                                   (PList.accession = Accession) AND (SFN = '223')) AS f233,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '201') OR
                                                   (PList.accession = Accession) AND (SFN = '202') OR
                                                   (PList.accession = Accession) AND (SFN = '203') OR
                                                   (PList.accession = Accession) AND (SFN = '204') OR
                                                   (PList.accession = Accession) AND (SFN = '205') OR
                                                   (PList.accession = Accession) AND (SFN = '219') OR
                                                   (PList.accession = Accession) AND (SFN = '209') OR
                                                   (PList.accession = Accession) AND (SFN = '310') OR
                                                   (PList.accession = Accession) AND (SFN = '308') OR
                                                   (PList.accession = Accession) AND (SFN = '311') OR
                                                   (PList.accession = Accession) AND (SFN = '316') OR
                                                   (PList.accession = Accession) AND (SFN = '312') OR
                                                   (PList.accession = Accession) AND (SFN = '313') OR
                                                   (PList.accession = Accession) AND (SFN = '314') OR
                                                   (PList.accession = Accession) AND (SFN = '315') OR
                                                   (PList.accession = Accession) AND (SFN = '318') OR
                                                   (PList.accession = Accession) AND (SFN = '220') OR
                                                   (PList.accession = Accession) AND (SFN = '22F') OR
                                                   (PList.accession = Accession) AND (SFN = '221') OR
                                                   (PList.accession = Accession) AND (SFN = '222') OR
                                                   (PList.accession = Accession) AND (SFN = '223')) AS f234,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '241')) AS f241,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '242')) AS f242,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '243')) AS f243,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '244')) AS f244,
                          (SELECT     ISNULL(SUM(Amt), 0) AS Expr1
                            FROM          dbo.ProjectSFN AS PSFN
                            WHERE      (PList.accession = Accession) AND (SFN = '241') OR
                                                   (PList.accession = Accession) AND (SFN = '242') OR
                                                   (PList.accession = Accession) AND (SFN = '243') OR
                                                   (PList.accession = Accession) AND (SFN = '244')) AS f350
FROM         dbo.ProjectsList AS PList
ORDER BY dept, proj

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
         Begin Table = "PList"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 125
               Right = 198
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ReportsList';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'ReportsList';

