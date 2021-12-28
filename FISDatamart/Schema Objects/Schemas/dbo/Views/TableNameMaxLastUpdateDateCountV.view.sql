CREATE VIEW [dbo].[TableNameMaxLastUpdateDateCountV]
AS
SELECT     'Accounts' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.Accounts
UNION
SELECT     'AccountType' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.AccountType
UNION
SELECT     'ARC_Codes' TableName, MAX(DS_Last_Update_Date) LastUpdateDate, Count(*) Count, 'R' TableType, 'M' UpdateMethod
FROM         dbo.ARC_Codes
UNION
SELECT     'BalanceTypes' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.BalanceTypes
UNION
SELECT     'BaseBudgetSubFundGroups' TableName, NULL LastUpdateDate, Count(*) Count, 'R' TableType, 'M' UpdateMethod
FROM         dbo.BaseBudgetSubFundGroups
UNION
SELECT     'BillingIDConversions' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.BillingIDConversions
UNION
SELECT     'DocumentOriginCodes' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.DocumentOriginCodes
UNION
SELECT     'DocumentTypes' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.DocumentTypes
UNION
SELECT     'FunctionCode' TableName, NULL LastUpdateDate, Count(*) Count, 'R' TableType, 'M' UpdateMethod
FROM         dbo.FunctionCode
UNION
SELECT     'FundGroups' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.FundGroups
UNION
SELECT     'GeneralLedgerProjectBalanceForAllPeriods' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.GeneralLedgerProjectBalanceForAllPeriods
UNION
SELECT     'HigherEducationFunctionCodes' TableName, MAX(LastUpdateDate), Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.HigherEducationFunctionCodes
UNION
SELECT     'Objects' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.Objects
UNION
SELECT     'ObjectSubTypes' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.ObjectSubTypes
UNION
SELECT     'ObjectTypes' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.ObjectTypes
UNION
SELECT     'OPFund' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.OPFund
UNION
SELECT     'Organizations' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.Organizations
UNION
SELECT     'Projects' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.Projects
UNION
SELECT     'SubAccounts' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.SubAccounts
UNION
SELECT     'SubFundGroups' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.SubFundGroups
UNION
SELECT     'SubFundGroupTypes' TableName, NULL LastUpdateDate, Count(*) Count, 'R' TableType, 'A' UpdateMethod
FROM         dbo.SubFundGroupTypes
UNION
SELECT     'SubObjects' TableName, MAX(LastUpdateDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.SubObjects
UNION
SELECT     'Trans' TableName, MAX(ChangeDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.Trans
UNION
SELECT     'PendingTrans' TableName, MAX(InitDate) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.PendingTrans
UNION
SELECT     'TransLog' TableName, ISNULL(MAX(TransChangeDate), MAX(TransInitDate)) LastUpdateDate, Count(*) Count, 'D' TableType, 'A' UpdateMethod
FROM         dbo.TransLog

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TableNameMaxLastUpdateDateCountV';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TableNameMaxLastUpdateDateCountV';



