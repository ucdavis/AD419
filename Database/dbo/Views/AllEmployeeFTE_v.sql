CREATE VIEW dbo.AllEmployeeFTE_v
AS
SELECT        TOP (100) PERCENT ISNULL(t1.EmployeeName, P.FullName) AS EmployeeName, t1.EmployeeID, t1.PayPeriodEndDate, t1.TitleCd, t1.Chart, t1.Org, 
                         t1.ExcludedByAccount, t1.Account, t1.ObjConsol, t1.FinanceDocTypeCd, t1.DosCd, t1.AnnualReportCode, t1.ExcludedByARC, t1.ExcludedByOrg, t1.Payrate, 
                         t1.Amount, t1.FTE, t1.RateTypeCd, COALESCE (A.ProjectNumber, PN.ProjectNumber) AS ProjectNumber, 
                         CASE WHEN t1.[ExcludedByARC] = 0 THEN t1.FTE ELSE 0 END AS InclFTE, ISNULL(st.AD419_Line_Num, '244') AS FTE_SFN, MAX(O.OrgR) AS OrgR
FROM            (SELECT        EmployeeID, EmployeeName, PayPeriodEndDate, Chart, Account, Org, ObjConsol, FinanceDocTypeCd, DosCd, TitleCd, AnnualReportCode, RateTypeCd, 
                                                    Payrate, SUM(Amount) AS Amount, ExcludedByOrg, ExcludedByARC, ExcludedByAccount, CASE WHEN [FinanceDocTypeCd] IN
                                                        (SELECT        t1.DocumentType
                                                          FROM            dbo.[FinanceDocTypesForFTECalc] t1) AND ObjConsol IN
                                                        (SELECT        Obj_Consolidatn_Num
                                                          FROM            dbo.[ConsolCodesForFTECalc]) AND DosCd IN
                                                        (SELECT        DOS_Code
                                                          FROM            dbo.DOSCodes) AND [PayRate] <> 0 THEN CASE WHEN [RateTypeCd] = 'H' THEN SUM(Amount) / ([PayRate] * 2088) 
                                                    ELSE SUM(Amount) / [PayRate] / 12 END ELSE 0 END AS FTE
                          FROM            dbo.AnotherLaborTransactions
                          WHERE        (EmployeeID IN
                                                        (SELECT DISTINCT EmployeeID
                                                          FROM            (SELECT        EmployeeID, EmployeeName, CONVERT(DECIMAL(18, 4), CASE WHEN [FinanceDocTypeCd] IN
                                                                                                                  (SELECT        DocumentType
                                                                                                                    FROM            dbo.[FinanceDocTypesForFTECalc]) AND ObjConsol IN
                                                                                                                  (SELECT        Obj_Consolidatn_Num
                                                                                                                    FROM            dbo.[ConsolCodesForFTECalc]) AND DosCd IN
                                                                                                                  (SELECT        DOS_Code
                                                                                                                    FROM            dbo.DOSCodes) AND [PayRate] <> 0 THEN CASE WHEN [RateTypeCd] = 'H' THEN SUM(Amount) 
                                                                                                              / ([PayRate] * 2088) ELSE SUM(Amount) / [PayRate] / 12 END ELSE 0 END) AS FTE
                                                                                    FROM            dbo.AnotherLaborTransactions AS AnotherLaborTransactions_1
                                                                                    WHERE        (ExcludedByOrg = 0) AND (ExcludedByARC = 0)
                                                                                    GROUP BY EmployeeID, EmployeeName, FinanceDocTypeCd, ObjConsol, Payrate, RateTypeCd, DosCd) AS t1_1
                                                          GROUP BY EmployeeID, EmployeeName
                                                          HAVING         (dbo.AnotherLaborTransactions.ObjConsol IN
                                                                                        (SELECT        Obj_Consolidatn_Num
                                                                                          FROM            dbo.ConsolCodesForFTECalc)) AND (dbo.AnotherLaborTransactions.DosCd IN
                                                                                        (SELECT        DOS_Code
                                                                                          FROM            dbo.DOSCodes))))
                          GROUP BY PayPeriodEndDate, Chart, Account, Org, ObjConsol, FinanceDocTypeCd, DosCd, EmployeeID, EmployeeName, TitleCd, AnnualReportCode, 
                                                    ExcludedByARC, ExcludedByOrg, ExcludedByAccount, Payrate, RateTypeCd) AS t1 LEFT OUTER JOIN
                         [$(PPSDataMart)].dbo.Titles AS T ON t1.TitleCd = T.TitleCode LEFT OUTER JOIN
                         dbo.staff_type AS st ON T.StaffType = st.Staff_Type_Code LEFT OUTER JOIN
                         dbo.OrgR_Lookup AS O ON t1.Org = O.Org LEFT OUTER JOIN
                         dbo.AllAccountsFor204Projects AS A ON t1.Chart = A.Chart AND t1.Account = A.Account LEFT OUTER JOIN
                         [$(PPSDataMart)].dbo.Persons AS P ON t1.EmployeeID = P.EmployeeID LEFT OUTER JOIN
                         dbo.FFY_SFN_Entries AS PS ON t1.Chart = PS.Chart AND t1.Account = PS.Account LEFT OUTER JOIN
                         dbo.AllProjectsNew AS PN ON PS.AccessionNumber = PN.AccessionNumber
GROUP BY t1.EmployeeName, t1.EmployeeID, t1.PayPeriodEndDate, t1.TitleCd, t1.Chart, t1.Org, t1.ExcludedByAccount, t1.Account, t1.ObjConsol, t1.FinanceDocTypeCd, 
                         t1.DosCd, t1.AnnualReportCode, t1.ExcludedByARC, t1.ExcludedByOrg, t1.Payrate, t1.Amount, t1.FTE, t1.RateTypeCd, ISNULL(st.AD419_Line_Num, '244'), 
                         A.ProjectNumber, PN.ProjectNumber, P.FullName, PS.AccessionNumber
ORDER BY EmployeeName, t1.EmployeeID, t1.PayPeriodEndDate, t1.TitleCd, t1.Chart, t1.Org, t1.ExcludedByAccount, t1.Account, t1.ObjConsol, t1.FinanceDocTypeCd, t1.DosCd, 
                         t1.AnnualReportCode, t1.ExcludedByARC, t1.ExcludedByOrg, t1.Payrate, t1.RateTypeCd, FTE_SFN, ProjectNumber
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AllEmployeeFTE_v';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'
         Begin Table = "PN"
            Begin Extent = 
               Top = 270
               Left = 297
               Bottom = 399
               Right = 505
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AllEmployeeFTE_v';


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
               Right = 248
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "T"
            Begin Extent = 
               Top = 6
               Left = 286
               Bottom = 135
               Right = 557
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "st"
            Begin Extent = 
               Top = 6
               Left = 595
               Bottom = 135
               Right = 825
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "O"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 250
               Right = 224
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "A"
            Begin Extent = 
               Top = 138
               Left = 262
               Bottom = 267
               Right = 501
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "P"
            Begin Extent = 
               Top = 138
               Left = 539
               Bottom = 267
               Right = 784
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "PS"
            Begin Extent = 
               Top = 252
               Left = 38
               Bottom = 381
               Right = 259
            End
            DisplayFlags = 280
            TopColumn = 0
         End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AllEmployeeFTE_v';

