CREATE VIEW [dbo].[TransactionLogV_MultiColumnJoins]
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
                         CASE WHEN TransV.BalType = 'AC' THEN TransV.LineAmount ELSE 0 END AS ExpendAmount, 
                         CASE WHEN TransV.BalType = 'CB' THEN TransV.LineAmount ELSE 0 END AS AppropAmount, CASE WHEN TransV.BalType IN ('EX', 'IE') 
                         THEN TransV.LineAmount ELSE 0 END AS EncumbAmount, dbo.TransV.OrgRefNum AS TransLineReference, 
                         dbo.TransV.PriorDocTypeNum AS TransPriorDocTypeNum, dbo.TransV.PriorDocOriginCd AS TransPriorDocOrigin, dbo.TransV.PriorDocNum AS TransPriorDocNum, 
                         dbo.TransV.EncumUpdtCd AS TransEncumUpdateCode, dbo.TransV.CreationDate AS TransCreationDate, dbo.TransV.PostDate AS TransPostDate, 
                         dbo.TransV.ReversalDate AS TransReversalDate, dbo.TransV.ChangeDate AS TransChangeDate, dbo.TransV.SrcTblCd AS TransSourceTableCode, 
                         dbo.TransV.IsPending AS IsPendingTrans, dbo.TransV.IsCAES AS IsCAESTrans
FROM            dbo.TransV INNER JOIN
                         dbo.Accounts ON dbo.TransV.Year = dbo.Accounts.Year AND dbo.TransV.Period = dbo.Accounts.Period AND dbo.TransV.Chart = dbo.Accounts.Chart AND 
                         dbo.TransV.Account = dbo.Accounts.Account INNER JOIN
                         dbo.OrganizationsV AS Organizations ON dbo.Accounts.Year = Organizations.Year AND dbo.Accounts.Period = Organizations.Period AND 
                         dbo.Accounts.Chart = Organizations.Chart AND dbo.Accounts.Org = Organizations.Org INNER JOIN
                         dbo.Objects ON dbo.TransV.Year = dbo.Objects.Year AND dbo.TransV.Chart = dbo.Objects.Chart AND dbo.TransV.Object = dbo.Objects.Object INNER JOIN
                         dbo.OPFund ON dbo.Accounts.Year = dbo.OPFund.Year AND dbo.Accounts.Period = dbo.OPFund.Period AND dbo.Accounts.Chart = dbo.OPFund.Chart AND 
                         dbo.Accounts.OpFundNum = dbo.OPFund.FundNum LEFT OUTER JOIN
                         dbo.FunctionCode ON dbo.Accounts.FunctionCodeID = dbo.FunctionCode.FunctionCodeID INNER JOIN
                         dbo.SubFundGroups ON dbo.OPFund.Year = dbo.SubFundGroups.Year AND dbo.OPFund.Period = dbo.SubFundGroups.Period AND 
                         dbo.OPFund.SubFundGroupNum = dbo.SubFundGroups.SubFundGroupNum INNER JOIN
                         dbo.SubFundGroupTypes ON dbo.SubFundGroups.SubFundGroupType = dbo.SubFundGroupTypes.SubFundGroupType LEFT OUTER JOIN
                         dbo.Projects ON dbo.TransV.Year = dbo.Projects.Year AND dbo.TransV.Period = dbo.Projects.Period AND dbo.TransV.Chart = dbo.Projects.Chart AND 
                         dbo.TransV.Project = dbo.Projects.Number LEFT OUTER JOIN
                         dbo.SubAccounts ON dbo.TransV.Year = dbo.SubAccounts.Year AND dbo.TransV.Period = dbo.SubAccounts.Period AND 
                         dbo.TransV.Chart = dbo.SubAccounts.Chart AND dbo.TransV.Account = dbo.SubAccounts.Account AND 
                         dbo.TransV.SubAccount = dbo.SubAccounts.SubAccount LEFT OUTER JOIN
                         dbo.DocumentTypes ON dbo.TransV.DocType = dbo.DocumentTypes.DocumentType INNER JOIN
                         dbo.FundGroups ON dbo.Accounts.FundGroupCode = dbo.FundGroups.FundGroup

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransactionLogV_MultiColumnJoins';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'yFlags = 280
            TopColumn = 0
         End
         Begin Table = "SubFundGroupTypes"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 399
               Right = 316
            End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransactionLogV_MultiColumnJoins';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'2', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TransactionLogV_MultiColumnJoins';



