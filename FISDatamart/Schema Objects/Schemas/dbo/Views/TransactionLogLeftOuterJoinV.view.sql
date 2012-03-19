CREATE VIEW [dbo].[TransactionLogLeftOuterJoinV]
AS
SELECT        dbo.TransV.PKTrans, dbo.TransV.OrganizationFK, dbo.TransV.Year AS FiscalYear, dbo.TransV.Period AS FiscalPeriod, dbo.TransV.Chart, 
                         dbo.Accounts.Org AS OrgCode, Organizations.Name AS OrgName, Organizations.[Level] AS OrgLevel, Organizations.Type AS OrgType, 
                         Organizations.Org1 AS Level1_OrgCode, Organizations.Name1 AS Level1_OrgName, Organizations.Org2 AS Level2_OrgCode, 
                         Organizations.Name2 AS Level2_OrgName, Organizations.OrgR AS Level3_OrgCode, Organizations.NameR AS Level3_OrgName, 
                         dbo.TransV.Chart + '-' + dbo.TransV.Account AS Account, dbo.TransV.Account AS AccountNum, dbo.Accounts.AccountName, 
                         dbo.Accounts.MgrName AS AccountManager, dbo.Accounts.PrincipalInvestigatorName AS PrincipalInvestigator, dbo.Accounts.TypeCode AS AccountType, 
                         dbo.Accounts.Purpose AS AccountPurpose, dbo.Accounts.FederalAgencyCode, dbo.Accounts.AwardNum AS AccountAwardNumber, 
                         dbo.Accounts.AwardTypeCode AS AccountAwardType, dbo.Accounts.AwardAmount AS AccountAwardAmount, dbo.Accounts.AwardEndDate AS AccountAwardEndDate, 
                         dbo.Accounts.HigherEdFuncCode AS HigherEdFunctionCode, dbo.FunctionCode.FunctionCode AS AccountFunctionCode, dbo.Accounts.A11AcctNum AS OPAccount, 
                         CONVERT(varchar(6), dbo.Accounts.OpFundNum) AS OPFund, dbo.OPFund.FundName AS OPFundName, dbo.Accounts.OpFundGroupCode AS OPFundGroup, 
                         dbo.OPFund.FundGroupName AS OPFundGroupName, dbo.Accounts.FundGroupCode AS AccountFundGroup, 
                         dbo.FundGroups.FundGroupName AS AccountFundGroupName, dbo.Accounts.SubFundGroupNum AS SubFundGroup, dbo.SubFundGroups.SubFundGroupName, 
                         dbo.Accounts.SubFundGroupTypeCode AS SubFundGroupType, dbo.SubFundGroupTypes.SubFundGroupTypeName, dbo.Accounts.AnnualReportCode, 
                         dbo.TransV.SubAccount, dbo.SubAccounts.SubAccountName, dbo.TransV.Object AS ObjectCode, dbo.Objects.Name AS ObjectName, 
                         dbo.Objects.ShortName AS ObjectShortName, dbo.Objects.BudgetAggregationCode, dbo.Objects.TypeCode AS ObjectType, 
                         dbo.Objects.TypeName AS ObjectTypeName, dbo.Objects.LevelName AS ObjectLevelName, dbo.Objects.ObjectLevelShortName, 
                         dbo.Objects.LevelCode AS ObjectLevelCode, dbo.Objects.SubTypeCode AS ObjectSubType, dbo.Objects.SubTypeName AS ObjectSubTypeName, 
                         dbo.Objects.ConsolidatnCode AS ConsolidationCode, dbo.Objects.ConsolidatnName AS ConsolidationName, 
                         dbo.Objects.ConsolidatnShortName AS ConsolidationShortName, dbo.TransV.SubObject, dbo.TransV.Project AS ProjectCode, dbo.Projects.Name AS ProjectName, 
                         dbo.Projects.ManagerID AS ProjectManager, dbo.Projects.Description AS ProjectDescription, dbo.TransV.DocType AS TransDocType, 
                         dbo.DocumentTypes.DocumentTypeName AS TransDocTypeName, dbo.TransV.DocOrigin AS TransDocOrigin, 
                         dbo.TransV.DocOrigin + '-' + dbo.TransV.DocNum AS DocumentNumber, dbo.TransV.DocNum AS TransDocNum, dbo.TransV.DocTrackNum AS TransDocTrackNum, 
                         dbo.TransV.InitrID AS TransDocInitiator, dbo.TransV.InitDate AS TransInitDate, dbo.TransV.LineSquenceNumber AS LineSequenceNum, 
                         dbo.TransV.LineDesc AS TransDescription, dbo.TransV.LineAmount AS TransLineAmount, dbo.TransV.BalType AS TransBalanceType, 
                         CASE WHEN dbo.TransV.BalType = 'AC' THEN dbo.TransV.LineAmount ELSE 0 END AS ExpendAmount, 
                         CASE WHEN dbo.TransV.BalType = 'CB' THEN dbo.TransV.LineAmount ELSE 0 END AS AppropAmount, CASE WHEN dbo.TransV.BalType IN ('EX', 'IE') 
                         THEN dbo.TransV.LineAmount ELSE 0 END AS EncumbAmount, dbo.TransV.OrgRefNum AS TransLineReference, 
                         dbo.TransV.PriorDocTypeNum AS TransPriorDocTypeNum, dbo.TransV.PriorDocOriginCd AS TransPriorDocOrigin, dbo.TransV.PriorDocNum AS TransPriorDocNum, 
                         dbo.TransV.EncumUpdtCd AS TransEncumUpdateCode, dbo.TransV.CreationDate AS TransCreationDate, dbo.TransV.PostDate AS TransPostDate, 
                         dbo.TransV.ReversalDate AS TransReversalDate, dbo.TransV.ChangeDate AS TransChangeDate, dbo.TransV.SrcTblCd AS TransSourceTableCode, 
                         dbo.TransV.IsPending AS IsPendingTrans, dbo.TransV.IsCAES AS IsCAESTrans
FROM            dbo.TransV LEFT OUTER JOIN
                         dbo.Accounts ON dbo.TransV.AccountsFK = dbo.Accounts.AccountPK LEFT OUTER JOIN
                         dbo.OrganizationsV AS Organizations ON dbo.Accounts.OrgFK = Organizations.OrganizationPK LEFT OUTER JOIN
                         dbo.Objects ON dbo.TransV.ObjectsFK = dbo.Objects.ObjectPK LEFT OUTER JOIN
                         dbo.OPFund ON dbo.Accounts.OPFundFK = dbo.OPFund.OPFundPK LEFT OUTER JOIN
                         dbo.FunctionCode ON dbo.Accounts.FunctionCodeID = dbo.FunctionCode.FunctionCodeID LEFT OUTER JOIN
                         dbo.SubFundGroups ON dbo.OPFund.SubFundGroupFK = dbo.SubFundGroups.SubFundGroupPK LEFT OUTER JOIN
                         dbo.SubFundGroupTypes ON dbo.SubFundGroups.SubFundGroupType = dbo.SubFundGroupTypes.SubFundGroupType LEFT OUTER JOIN
                         dbo.Projects ON dbo.TransV.ProjectFK = dbo.Projects.ProjectsPK LEFT OUTER JOIN
                         dbo.SubAccounts ON dbo.TransV.SubAccountFK = dbo.SubAccounts.SubAccountPK LEFT OUTER JOIN
                         dbo.DocumentTypes ON dbo.TransV.DocType = dbo.DocumentTypes.DocumentType LEFT OUTER JOIN
                         dbo.FundGroups ON dbo.Accounts.FundGroupCode = dbo.FundGroups.FundGroup

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
            Disp', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransactionLogLeftOuterJoinV';


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
         Begin Table = "DocumentTypes"
            Begin Extent = 
               Top = 402
               Left = 38
               Bottom = 531
               Right = 311
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "FundGroups"
            Begin Extent = 
               Top = 402
               Left = 349
               Bottom = 514
               Right = 530
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
End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransactionLogLeftOuterJoinV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransactionLogLeftOuterJoinV';

