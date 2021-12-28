CREATE VIEW [dbo].[OrgAccountsBenefitsDiversionV]
AS
SELECT        ISNULL(dbo.OrganizationsV.Org3, dbo.OrganizationsV.Org) AS Org, dbo.Accounts.Chart, dbo.Accounts.Account, dbo.BenefitsDiversionV.OpFundNum, 
                         dbo.BenefitsDiversionV.LevelCode, dbo.BenefitsDiversionV.ReportsToChart, dbo.BenefitsDiversionV.ReportsToAccount, 
                         dbo.BenefitsDiversionV.ReportsToSubAccount, dbo.BenefitsDiversionV.ReportsToProject, dbo.BenefitsDiversionV.ActiveInd, 
                         dbo.BenefitsDiversionV.LastUpdateDate, dbo.Accounts.ExpirationDate
FROM            dbo.Accounts INNER JOIN
                         dbo.OrganizationsV ON dbo.Accounts.Chart = dbo.OrganizationsV.Chart AND dbo.Accounts.Org = dbo.OrganizationsV.Org AND 
                         dbo.Accounts.Year = dbo.OrganizationsV.Year AND dbo.Accounts.Period = dbo.OrganizationsV.Period LEFT OUTER JOIN
                         dbo.BenefitsDiversionV ON dbo.Accounts.Chart = dbo.BenefitsDiversionV.Chart AND dbo.Accounts.Account = dbo.BenefitsDiversionV.Account
WHERE        (dbo.Accounts.Year = 9999) AND (dbo.Accounts.Period = '--')
GROUP BY ISNULL(dbo.OrganizationsV.Org3, dbo.OrganizationsV.Org), dbo.Accounts.Chart, dbo.Accounts.Account, dbo.BenefitsDiversionV.OpFundNum, 
                         dbo.BenefitsDiversionV.LevelCode, dbo.BenefitsDiversionV.ReportsToChart, dbo.BenefitsDiversionV.ReportsToAccount, 
                         dbo.BenefitsDiversionV.ReportsToSubAccount, dbo.BenefitsDiversionV.ReportsToProject, dbo.BenefitsDiversionV.ActiveInd, 
                         dbo.BenefitsDiversionV.LastUpdateDate, dbo.Accounts.ExpirationDate
HAVING        (dbo.Accounts.ExpirationDate IS NULL) OR
                         (dbo.Accounts.ExpirationDate >= GETDATE())
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'OrgAccountsBenefitsDiversionV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'OrgAccountsBenefitsDiversionV';

