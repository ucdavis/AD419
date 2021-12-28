
CREATE VIEW [dbo].[BaseBudgetV]
AS
SELECT        dbo.TransV.Year, dbo.TransV.Period, dbo.TransV.Chart, dbo.Accounts.Org AS OrgID, dbo.TransV.Account, dbo.TransV.SubAccount, dbo.TransV.Object, 
                         dbo.TransV.SubObject, dbo.TransV.BalType, dbo.TransV.DocType, dbo.TransV.DocOrigin, dbo.TransV.DocNum, dbo.TransV.DocTrackNum, dbo.TransV.InitrID, 
                         dbo.TransV.InitDate, dbo.TransV.LineSquenceNumber, dbo.TransV.LineDesc, dbo.TransV.LineAmount, dbo.TransV.Project, dbo.TransV.OrgRefNum, 
                         dbo.TransV.PriorDocTypeNum, dbo.TransV.PriorDocOriginCd, dbo.TransV.PriorDocNum, dbo.TransV.EncumUpdtCd, dbo.TransV.CreationDate, dbo.TransV.PostDate, 
                         dbo.TransV.ReversalDate, dbo.TransV.ChangeDate, dbo.TransV.SrcTblCd, dbo.Accounts.OrgFK AS OrganizationFK, dbo.TransV.AccountsFK, dbo.TransV.ObjectsFK, 
                         dbo.TransV.SubObjectFK, dbo.TransV.SubAccountFK, dbo.TransV.IsCAES, dbo.TransV.IsPending, dbo.FunctionCode.FunctionCode, dbo.Accounts.OpFundNum, 
                         dbo.Accounts.SubFundGroupNum
FROM            dbo.TransV INNER JOIN
                         dbo.Accounts ON dbo.TransV.AccountsFK = dbo.Accounts.AccountPK INNER JOIN
                         dbo.FunctionCode ON dbo.Accounts.FunctionCodeID = dbo.FunctionCode.FunctionCodeID
WHERE        (dbo.TransV.BalType IN ('BB', 'BI', 'FT', 'FI'))

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
         Top = -96
         Left = 0
      End
      Begin Tables = 
         Begin Table = "TransV"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 238
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Accounts"
            Begin Extent = 
               Top = 6
               Left = 276
               Bottom = 135
               Right = 505
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "FunctionCode"
            Begin Extent = 
               Top = 6
               Left = 543
               Bottom = 118
               Right = 718
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BaseBudgetV';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BaseBudgetV';

