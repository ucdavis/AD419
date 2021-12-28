﻿CREATE VIEW [dbo].[BATransactionLogV]
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
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'2', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BATransactionLogV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'= 280
            TopColumn = 0
         End
         Begin Table = "DocumentTypes"
            Begin Extent = 
               Top = 138
               Left = 472
               Bottom = 267
               Right = 745
            End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BATransactionLogV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'BATransactionLogV';
