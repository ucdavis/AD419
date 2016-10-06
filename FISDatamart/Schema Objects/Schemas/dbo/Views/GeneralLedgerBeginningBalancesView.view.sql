CREATE VIEW dbo.GeneralLedgerBeginningBalancesView
AS
SELECT     CONVERT(CHAR(4), TransV.Year) 
                      + '|' + '00' + '|' + TransV.Chart + '|' + TransV.Account + '|' + TransV.SubAccount + '|' + TransV.ObjectType + '|' + TransV.Object + '|' + TransV.SubObject + '|' + TransV.BalType
                       + '|' + '' + '|' + '' + '|' + '' + '|' + '' + '|' + '' + '|' + CONVERT(varchar(20), TransV.BalanceCreateDate, 112) AS PKTrans, Organizations.OrganizationPK AS OrganizationFK, 
                      TransV.Year AS FiscalYear, '00' AS FiscalPeriod, TransV.Chart, dbo.Accounts.Org AS OrgCode, Organizations.Name AS OrgName, Organizations.[Level] AS OrgLevel, 
                      Organizations.Type AS OrgType, Organizations.Org1 AS Level1_OrgCode, Organizations.Name1 AS Level1_OrgName, Organizations.Org2 AS Level2_OrgCode, 
                      Organizations.Name2 AS Level2_OrgName, Organizations.OrgR AS Level3_OrgCode, Organizations.NameR AS Level3_OrgName, 
                      TransV.Chart + '-' + TransV.Account AS Account, TransV.Account AS AccountNum, dbo.Accounts.AccountName, dbo.Accounts.MgrName AS AccountManager, 
                      dbo.Accounts.PrincipalInvestigatorName AS PrincipalInvestigator, dbo.Accounts.TypeCode AS AccountType, dbo.Accounts.Purpose AS AccountPurpose, 
                      dbo.Accounts.FederalAgencyCode, dbo.Accounts.AwardNum AS AccountAwardNumber, dbo.Accounts.AwardTypeCode AS AccountAwardType, 
                      dbo.Accounts.AwardAmount AS AccountAwardAmount, dbo.Accounts.AwardEndDate AS AccountAwardEndDate, 
                      dbo.Accounts.HigherEdFuncCode AS HigherEdFunctionCode, dbo.FunctionCode.FunctionCode AS AccountFunctionCode, dbo.Accounts.A11AcctNum AS OPAccount, 
                      CONVERT(varchar(6), dbo.Accounts.OpFundNum) AS OPFund, dbo.OPFund.FundName AS OPFundName, dbo.Accounts.OpFundGroupCode AS OPFundGroup, 
                      dbo.OPFund.FundGroupName AS OPFundGroupName, dbo.Accounts.FundGroupCode AS AccountFundGroup, 
                      dbo.FundGroups.FundGroupName AS AccountFundGroupName, dbo.Accounts.SubFundGroupNum AS SubFundGroup, dbo.SubFundGroups.SubFundGroupName, 
                      dbo.Accounts.SubFundGroupTypeCode AS SubFundGroupType, dbo.SubFundGroupTypes.SubFundGroupTypeName, dbo.Accounts.AnnualReportCode, 
                      dbo.Accounts.FringeBenefitIndicator, dbo.Accounts.FringeBenefitChart, dbo.Accounts.FringeBenefitAccount, TransV.SubAccount, dbo.SubAccounts.SubAccountName, 
                      TransV.Object AS ObjectCode, dbo.Objects.Name AS ObjectName, dbo.Objects.ShortName AS ObjectShortName, dbo.Objects.BudgetAggregationCode, 
                      dbo.Objects.TypeCode AS ObjectType, dbo.Objects.TypeName AS ObjectTypeName, dbo.Objects.LevelName AS ObjectLevelName, 
                      dbo.Objects.ObjectLevelShortName, dbo.Objects.LevelCode AS ObjectLevelCode, dbo.Objects.SubTypeCode AS ObjectSubType, 
                      dbo.Objects.SubTypeName AS ObjectSubTypeName, dbo.Objects.ConsolidatnCode AS ConsolidationCode, dbo.Objects.ConsolidatnName AS ConsolidationName, 
                      dbo.Objects.ConsolidatnShortName AS ConsolidationShortName, TransV.SubObject, TransV.Project AS ProjectCode, dbo.Projects.Name AS ProjectName, 
                      dbo.Projects.ManagerID AS ProjectManager, dbo.Projects.Description AS ProjectDescription, CONVERT(char(4), NULL) AS TransDocType, CONVERT(varchar(40), NULL) 
                      AS TransDocTypeName, CONVERT(char(2), NULL) AS TransDocOrigin, CONVERT(varchar(12), NULL) AS DocumentNumber, CONVERT(char(9), NULL) AS TransDocNum, 
                      CONVERT(char(10), NULL) AS TransDocTrackNum, CONVERT(char(8), NULL) AS TransDocInitiator, TransV.BalanceCreateDate AS TransInitDate, CONVERT(decimal(7, 
                      0), NULL) AS LineSequenceNum, CONVERT(varchar(40), NULL) AS TransDescription, TransV.FiscalYearBeginningBalance AS TransLineAmount, 
                      TransV.BalType AS TransBalanceType, CASE WHEN TransV.BalType = 'AC' THEN TransV.FiscalYearBeginningBalance ELSE 0 END AS ExpendAmount, 
                      CASE WHEN TransV.BalType = 'CB' THEN TransV.FiscalYearBeginningBalance ELSE 0 END AS AppropAmount, CASE WHEN TransV.BalType IN ('EX', 'IE') 
                      THEN TransV.FiscalYearBeginningBalance ELSE 0 END AS EncumbAmount, CONVERT(char(8), NULL) AS TransLineReference, CONVERT(char(4), NULL) 
                      AS TransPriorDocTypeNum, CONVERT(char(2), NULL) AS TransPriorDocOrigin, CONVERT(char(9), NULL) AS TransPriorDocNum, CONVERT(char(1), NULL) 
                      AS TransEncumUpdateCode, CONVERT(smalldatetime, TransV.BalanceCreateDate) AS TransCreationDate, CONVERT(smalldatetime, TransV.BalanceCreateDate) 
                      AS TransPostDate, CONVERT(smalldatetime, NULL) AS TransReversalDate, TransV.LastUpdateDate AS TransChangeDate, 'B' AS TransSourceTableCode, 
                      0 AS IsPendingTrans, CONVERT(tinyint, CASE WHEN Organizations.Org1 = 'BIOS' THEN 0 WHEN Organizations.Org1 = 'AAES' THEN 1 ELSE 2 END) 
                      AS IsCAESTrans
FROM         dbo.GeneralLedgerProjectBalanceForAllPeriods AS TransV INNER JOIN
                      dbo.Accounts ON TransV.Year = dbo.Accounts.Year AND TransV.Chart = dbo.Accounts.Chart AND TransV.Account = dbo.Accounts.Account AND 
                      dbo.Accounts.Period = '--' INNER JOIN
                      dbo.OrganizationsV AS Organizations ON dbo.Accounts.OrgFK = Organizations.OrganizationPK INNER JOIN
                      dbo.Objects ON TransV.Year = dbo.Objects.Year AND TransV.Chart = dbo.Objects.Chart AND TransV.Object = dbo.Objects.Object INNER JOIN
                      dbo.OPFund ON dbo.Accounts.OPFundFK = dbo.OPFund.OPFundPK LEFT OUTER JOIN
                      dbo.FunctionCode ON dbo.Accounts.FunctionCodeID = dbo.FunctionCode.FunctionCodeID INNER JOIN
                      dbo.SubFundGroups ON dbo.OPFund.SubFundGroupFK = dbo.SubFundGroups.SubFundGroupPK INNER JOIN
                      dbo.SubFundGroupTypes ON dbo.SubFundGroups.SubFundGroupType = dbo.SubFundGroupTypes.SubFundGroupType LEFT OUTER JOIN
                      dbo.Projects ON TransV.Year = dbo.Projects.Year AND TransV.Chart = dbo.Projects.Chart AND TransV.Project = dbo.Projects.Number AND 
                      dbo.Projects.Period = '--' LEFT OUTER JOIN
                      dbo.SubAccounts ON TransV.Year = dbo.SubAccounts.Year AND TransV.Chart = dbo.SubAccounts.Chart AND TransV.Account = dbo.SubAccounts.Account AND 
                      TransV.SubAccount = dbo.SubAccounts.SubAccount AND dbo.SubAccounts.Period = '--' LEFT OUTER JOIN
                      dbo.FundGroups ON dbo.Accounts.FundGroupCode = dbo.FundGroups.FundGroup

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'GeneralLedgerBeginningBalancesView: Uses the GeneralLedgerPeriodBalanceForAllPeriods to simulate the data returned by TransactionsLogV so that is can be unioned with TransactionLogV in order to return the beginning balances.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'GeneralLedgerBeginningBalancesView';


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
               Right = 329
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Accounts"
            Begin Extent = 
               Top = 6
               Left = 367
               Bottom = 135
               Right = 596
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Organizations"
            Begin Extent = 
               Top = 6
               Left = 634
               Bottom = 135
               Right = 813
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Objects"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 267
               Right = 259
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "OPFund"
            Begin Extent = 
               Top = 138
               Left = 297
               Bottom = 267
               Right = 493
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "FunctionCode"
            Begin Extent = 
               Top = 138
               Left = 531
               Bottom = 250
               Right = 706
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SubFundGroups"
            Begin Extent = 
               Top = 252
               Left = 531
               Bottom = 381
               Right = 788
            End
            Disp', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'GeneralLedgerBeginningBalancesView';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'layFlags = 280
            TopColumn = 0
         End
         Begin Table = "SubFundGroupTypes"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 399
               Right = 316
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Projects"
            Begin Extent = 
               Top = 270
               Left = 354
               Bottom = 399
               Right = 526
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SubAccounts"
            Begin Extent = 
               Top = 384
               Left = 564
               Bottom = 513
               Right = 750
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "FundGroups"
            Begin Extent = 
               Top = 138
               Left = 744
               Bottom = 250
               Right = 925
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'GeneralLedgerBeginningBalancesView';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'GeneralLedgerBeginningBalancesView';

