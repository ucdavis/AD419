CREATE VIEW dbo.BalanceSummaryView
AS
SELECT        PKTrans, FiscalYear, FiscalPeriod, Chart, Level1_OrgCode AS CollegeLevelOrg, Level2_OrgCode AS DivisionLevelOrg, Level3_OrgCode AS DepartmentLevelOrg, 
                         OrgCode, Account, AccountName, AccountAwardNumber, AccountAwardAmount, CONVERT(varchar(5), OPFund) AS OPFund, OPFundName, SubAccount, 
                         CASE WHEN [SubAccountName] IS NULL THEN '[default]' ELSE [SubAccountName] END AS SubAccountName, ConsolidationCode, ConsolidationName, ProjectCode, 
                         CASE WHEN ProjectName IS NULL THEN '[default]' ELSE ProjectName END AS ProjectName, TransBalanceType, SubFundGroup, SubFundGroupName, IsCAESTrans, 
                         TransSourceTableCode, IsPendingTrans, TransLineAmount AS Amount, AppropAmount AS Approp, ExpendAmount AS Expend, EncumbAmount AS Encumb, 
                         HigherEdFunctionCode, OPAccount, OPFundGroup, OPFundGroupName, PrincipalInvestigator, AccountNum, SubFundGroupType, SubFundGroupTypeName, OrgName,
                          OrgLevel, OrgType, Level1_OrgName, Level2_OrgName, Level3_OrgName, AccountManager, AccountType, AccountPurpose, FederalAgencyCode, 
                         AccountAwardType, AccountAwardEndDate, AccountFunctionCode, AccountFundGroup, AccountFundGroupName, AnnualReportCode, FringeBenefitIndicator, 
                         FringeBenefitChart, FringeBenefitAccount, ObjectCode, ObjectName, ObjectShortName, BudgetAggregationCode, ObjectType, ObjectTypeName, ObjectLevelName, 
                         ObjectLevelShortName, ObjectLevelCode, ObjectSubType, ObjectSubTypeName, ConsolidationShortName, SubObject, ProjectManager, ProjectDescription, 
                         TransDocType, TransDocTypeName, TransDocOrigin, TransDocInitiator, TransInitDate, TransDescription, TransPostDate
FROM            dbo.TransactionLogV
WHERE        (((TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode NOT IN ('LIEN', 'BLSH')) OR
                         (TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode = 'BLSH') AND (ObjectCode NOT IN ('0054', '9998', 'HIST'))))
UNION ALL
SELECT        PKTrans, FiscalYear, FiscalPeriod, Chart, Level1_OrgCode AS CollegeLevelOrg, Level2_OrgCode AS DivisionLevelOrg, Level3_OrgCode AS DepartmentLevelOrg, 
                         OrgCode, Account, AccountName, AccountAwardNumber, AccountAwardAmount, CONVERT(varchar(5), OPFund) AS OPFund, OPFundName, SubAccount, 
                         CASE WHEN [SubAccountName] IS NULL THEN '[default]' ELSE [SubAccountName] END AS SubAccountName, ConsolidationCode, ConsolidationName, ProjectCode, 
                         CASE WHEN ProjectName IS NULL THEN '[default]' ELSE ProjectName END AS ProjectName, TransBalanceType, SubFundGroup, SubFundGroupName, IsCAESTrans, 
                         TransSourceTableCode, IsPendingTrans, TransLineAmount AS Amount, AppropAmount AS Approp, ExpendAmount AS Expend, EncumbAmount AS Encumb, 
                         HigherEdFunctionCode, OPAccount, OPFundGroup, OPFundGroupName, PrincipalInvestigator, AccountNum, SubFundGroupType, SubFundGroupTypeName, OrgName,
                          OrgLevel, OrgType, Level1_OrgName, Level2_OrgName, Level3_OrgName, AccountManager, AccountType, AccountPurpose, FederalAgencyCode, 
                         AccountAwardType, AccountAwardEndDate, AccountFunctionCode, AccountFundGroup, AccountFundGroupName, AnnualReportCode, FringeBenefitIndicator, 
                         FringeBenefitChart, FringeBenefitAccount, ObjectCode, ObjectName, ObjectShortName, BudgetAggregationCode, ObjectType, ObjectTypeName, ObjectLevelName, 
                         ObjectLevelShortName, ObjectLevelCode, ObjectSubType, ObjectSubTypeName, ConsolidationShortName, SubObject, ProjectManager, ProjectDescription, 
                         TransDocType, TransDocTypeName, TransDocOrigin, TransDocInitiator, TransInitDate, TransDescription, TransPostDate
FROM            dbo.GeneralLedgerBeginningBalancesView
WHERE        (((TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode NOT IN ('LIEN', 'BLSH')) OR
                         (TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode = 'BLSH') AND (ObjectCode NOT IN ('0054', '9998', 'HIST'))))

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Summary View: Returns all the columns commonly used for a balance summary report.  It specifically excludes non-balance summary items such as base budget entries, entries with Consolidation codes LIEN and BLSH, but allows BLSH consolidation code entries that are objects ‘0000’, ‘9999’, ‘0060’, ''REAP''.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BalanceSummaryView';


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
         Top = -2784
         Left = 0
      End
      Begin Tables = 
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
         Column = 8205
         Alias = 1635
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BalanceSummaryView';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BalanceSummaryView';

