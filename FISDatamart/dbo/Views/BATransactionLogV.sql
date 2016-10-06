﻿CREATE VIEW dbo.BATransactionLogV
AS
SELECT        dbo.TransV.PKTrans, dbo.TransV.Year AS FiscalYear, dbo.TransV.Period AS FiscalPeriod, dbo.TransV.Chart, dbo.Accounts.Org AS OrgCode, 
                         Organizations.Name AS OrgName, Organizations.[Level] AS OrgLevel, Organizations.Type AS OrgType, Organizations.Org1 AS Level1_OrgCode, 
                         Organizations.Name1 AS Level1_OrgName, Organizations.Org2 AS Level2_OrgCode, Organizations.Name2 AS Level2_OrgName, 
                         Organizations.OrgR AS Level3_OrgCode, Organizations.NameR AS Level3_OrgName, dbo.TransV.Account AS AccountNum, dbo.Accounts.AccountName, 
                         dbo.Accounts.ExpirationDate AS AcctExpirationDate, dbo.Accounts.MgrName AS AccountManager, dbo.Accounts.MgrId AS AccountManagerId, 
                         dbo.Accounts.PrincipalInvestigatorName AS PrincipalInvestigator, dbo.Accounts.PrincipalInvestigatorId, dbo.Accounts.Purpose AS AccountPurpose, 
                         dbo.Accounts.HigherEdFuncCode AS HigherEdFunctionCode, dbo.Accounts.A11AcctNum AS OPAccount, CONVERT(varchar(6), dbo.Accounts.OpFundNum) AS OPFund, 
                         dbo.OPFund.FundName AS OPFundName, dbo.TransV.SubAccount, dbo.SubAccounts.SubAccountName, dbo.TransV.Object AS ObjectCode, 
                         dbo.Objects.Name AS ObjectName, dbo.Objects.ConsolidatnCode AS ConsolidationCode, dbo.Objects.ConsolidatnName AS ConsolidationName, 
                         dbo.Objects.ConsolidatnShortName AS ConsolidationShortName, dbo.TransV.SubObject, dbo.TransV.Project AS ProjectCode, dbo.Projects.Name AS ProjectName, 
                         dbo.Projects.ManagerID AS ProjectManager, dbo.Projects.Description AS ProjectDescription, dbo.TransV.DocType AS TransDocType, 
                         dbo.DocumentTypes.DocumentTypeName AS TransDocTypeName, dbo.TransV.LineAmount AS TransLineAmount, dbo.TransV.BalType AS TransBalanceType, 
                         CASE WHEN dbo.TransV.BalType = 'AC' THEN dbo.TransV.LineAmount ELSE 0 END AS ExpendAmount, 
                         CASE WHEN dbo.TransV.BalType = 'CB' THEN dbo.TransV.LineAmount ELSE 0 END AS AppropAmount, CASE WHEN dbo.TransV.BalType IN ('EX', 'IE') 
                         THEN dbo.TransV.LineAmount ELSE 0 END AS EncumbAmount, dbo.TransV.IsPending AS IsPendingTrans, dbo.TransV.IsCAES AS IsCAESTrans
FROM            dbo.TransV INNER JOIN
                         dbo.Accounts ON dbo.TransV.Chart = dbo.Accounts.Chart AND dbo.TransV.Year = dbo.Accounts.Year AND dbo.TransV.Period = dbo.Accounts.Period AND 
                         dbo.TransV.Account = dbo.Accounts.Account INNER JOIN
                         dbo.OrganizationsV AS Organizations ON dbo.Accounts.Chart = Organizations.Chart AND dbo.Accounts.Year = Organizations.Year AND 
                         dbo.Accounts.Period = Organizations.Period AND dbo.Accounts.Org = Organizations.Org LEFT OUTER JOIN
                         dbo.Objects ON dbo.TransV.Chart = dbo.Objects.Chart AND dbo.TransV.Year = dbo.Objects.Year AND dbo.TransV.Object = dbo.Objects.Object INNER JOIN
                         dbo.OPFund ON dbo.Accounts.Chart = dbo.OPFund.Chart AND dbo.Accounts.Year = dbo.OPFund.Year AND dbo.Accounts.Period = dbo.OPFund.Period AND 
                         dbo.Accounts.OpFundNum = dbo.OPFund.FundNum LEFT OUTER JOIN
                         dbo.Projects ON dbo.TransV.Chart = dbo.Projects.Chart AND dbo.TransV.Year = dbo.Projects.Year AND dbo.TransV.Period = dbo.Projects.Period AND 
                         dbo.TransV.Project = dbo.Projects.Number LEFT OUTER JOIN
                         dbo.SubAccounts ON dbo.TransV.Year = dbo.SubAccounts.Year AND dbo.TransV.Period = dbo.SubAccounts.Period AND 
                         dbo.TransV.Chart = dbo.SubAccounts.Chart AND dbo.TransV.Account = dbo.SubAccounts.Account AND 
                         dbo.TransV.SubAccount = dbo.SubAccounts.SubAccount LEFT OUTER JOIN
                         dbo.DocumentTypes ON dbo.TransV.DocType = dbo.DocumentTypes.DocumentType
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BATransactionLogV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N' = 280
            TopColumn = 0
         End
         Begin Table = "DocumentTypes"
            Begin Extent = 
               Top = 138
               Left = 472
               Bottom = 267
               Right = 745
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
      Begin ColumnWidths = 10
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
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 1800
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BATransactionLogV';


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
         Begin Table = "Organizations"
            Begin Extent = 
               Top = 6
               Left = 543
               Bottom = 135
               Right = 722
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Objects"
            Begin Extent = 
               Top = 6
               Left = 760
               Bottom = 135
               Right = 981
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "OPFund"
            Begin Extent = 
               Top = 6
               Left = 1019
               Bottom = 135
               Right = 1215
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Projects"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 267
               Right = 210
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SubAccounts"
            Begin Extent = 
               Top = 138
               Left = 248
               Bottom = 267
               Right = 434
            End
            DisplayFlags', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BATransactionLogV';

