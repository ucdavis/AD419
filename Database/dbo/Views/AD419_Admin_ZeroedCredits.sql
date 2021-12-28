/*
Title: AD419_Admin_ZeroedCredits
Author: Ken Taylor
Created: Octoberr 4, 2017
Description: View of [dbo].[AD419_Admin] table with negative amounts zeroed out for submission to ANR.

*/
CREATE VIEW dbo.AD419_Admin_ZeroedCredits
AS
SELECT        TOP (100) PERCENT loc, dept, proj, project, accession, PI, f201, f202, f203, f204, f205, f201 + f202 + f203 + f204 + f205 AS f231, f219, f209, f310, f308, f311, f316, f312, f313, f314, f315, f318, 
                         f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318 AS f332, f220, f22F, f221, f222, f223, f220 + f22F + f221 + f222 + f223 AS f233, 
                         f201 + f202 + f203 + f204 + f205 + f219 + f209 + f310 + f308 + f311 + f316 + f312 + f313 + f314 + f315 + f318 + f220 + f22F + f221 + f222 + f223 AS f234, f241, f242, f243, f244, f241 + f242 + f243 + f244 AS f350
FROM            (SELECT        loc, dept, proj, project, accession, PI, (f201 + ABS(f201)) / 2 AS f201, (f202 + ABS(f202)) / 2 AS f202, (f203 + ABS(f203)) / 2 AS f203, (f204 + ABS(f204)) / 2 AS f204, (f205 + ABS(f205)) / 2 AS f205, 
                                                    (f219 + ABS(f219)) / 2 AS f219, (f209 + ABS(f209)) / 2 AS f209, (f310 + ABS(f310)) / 2 AS f310, (f308 + ABS(f308)) / 2 AS f308, (f311 + ABS(f311)) / 2 AS f311, (f316 + ABS(f316)) / 2 AS f316, (f312 + ABS(f312))
                                                     / 2 AS f312, (f313 + ABS(f313)) / 2 AS f313, (f314 + ABS(f314)) / 2 AS f314, (f315 + ABS(f315)) / 2 AS f315, (f318 + ABS(f318)) / 2 AS f318, (f220 + ABS(f220)) / 2 AS f220, (f22F + ABS(f22F)) / 2 AS f22F, 
                                                    (f221 + ABS(f221)) / 2 AS f221, (f222 + ABS(f222)) / 2 AS f222, (f223 + ABS(f223)) / 2 AS f223, (f241 + ABS(f241)) / 2 AS f241, (f242 + ABS(f242)) / 2 AS f242, (f243 + ABS(f243)) / 2 AS f243, (f244 + ABS(f244))
                                                     / 2 AS f244
                          FROM            dbo.AD419_Admin) AS t1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AD419_Admin_ZeroedCredits';


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
               Right = 208
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AD419_Admin_ZeroedCredits';

