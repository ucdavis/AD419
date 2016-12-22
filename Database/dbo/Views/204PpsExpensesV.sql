CREATE VIEW dbo.[204PpsExpensesV]
AS
SELECT        TOP (100) PERCENT t1_1.Project, t1_1.Accession, t1_1.Exp_SFN, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, 
                         t3.AbbreviatedName AS Title_Code_Name, t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, SUM(t1_1.Expenses) AS Expenses, t1_1.IsExpired, 
                         1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t1_1.Exp_SFN AS Sub_Exp_SFN, SUM(t1_1.FTE) AS FTE, t4.AD419_Line_Num AS FTE_SFN, 
                         t4.Staff_Type_Short_Name AS Staff_Grp_Cd
FROM            (SELECT        t2.ProjectNumber AS Project, t2.AccessionNumber AS Accession, t2.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.EmployeeID AS EID, 
                                                    t1.EmployeeName AS Employee_Name, t1.TitleCd, t1.Chart, t1.Account, t1.SubAccount AS SubAcct, t1.PrincipalInvestigator AS PI_Name, SUM(t1.Amount) 
                                                    AS Expenses, t2.IsExpired, 1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t2.SFN AS Sub_Exp_SFN, SUM(t1.FTE) AS FTE
                          FROM            dbo.PPS_ExpensesFor204Projects AS t1 INNER JOIN
                                                    dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account INNER JOIN
                                                        (SELECT        AccessionNumber
                                                          FROM            dbo.FFY_SFN_Entries
                                                          WHERE        (IsExpired = 0) AND (SFN = '204')
                                                          GROUP BY AccessionNumber
                                                          HAVING         (SUM(Expenses) > 0)) AS t3_1 ON t2.AccessionNumber = t3_1.AccessionNumber
                          WHERE        (t2.SFN IN ('204')) AND (t2.AccessionNumber IS NOT NULL) AND (t2.IsExpired = 0)
                          GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t1.EmployeeID, t1.EmployeeName, t1.TitleCd, t2.SFN, t2.AccessionNumber, 
                                                    t2.ProjectNumber, t2.IsExpired
                          HAVING         (SUM(t1.Amount) <> 0)) AS t1_1 LEFT OUTER JOIN
                         PPSDataMart.dbo.Titles AS t3 ON t1_1.TitleCd = t3.TitleCode LEFT OUTER JOIN
                         dbo.staff_type AS t4 ON t3.StaffType = t4.Staff_Type_Code
GROUP BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, t3.AbbreviatedName, t1_1.Exp_SFN, 
                         t1_1.Accession, t1_1.Project, t1_1.IsExpired, t4.AD419_Line_Num, t4.Staff_Type_Short_Name
ORDER BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, Title_Code_Name, t1_1.Exp_SFN, 
                         t1_1.Accession, t1_1.Project, t1_1.IsExpired, FTE_SFN, Staff_Grp_Cd
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'204PpsExpensesV';


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
         Begin Table = "t3"
            Begin Extent = 
               Top = 6
               Left = 270
               Bottom = 135
               Right = 541
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t4"
            Begin Extent = 
               Top = 6
               Left = 579
               Bottom = 135
               Right = 809
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t1_1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
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
      Begin ColumnWidths = 9
         Width = 284
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'204PpsExpensesV';

