CREATE VIEW [dbo].[BalanceSummaryV]
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
FROM            dbo.TransLog
WHERE        (((TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode NOT IN ('LIEN', 'BLSH')) OR
                         (TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode = 'BLSH') AND ObjectCode NOT IN ('0054', '9998', 'HIST')))
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
                         (TransBalanceType IN ('CB', 'AC', 'EX', 'IE')) AND (ConsolidationCode = 'BLSH') AND ObjectCode NOT IN ('0054', '9998', 'HIST')))

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'BalanceSummaryV: This view unions data from the TransLog table and GeneralLedgerBeginningBalancesView so that it includes beginning balances which were previous omitted.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BalanceSummaryV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BalanceSummaryV';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BalanceSummaryV';



