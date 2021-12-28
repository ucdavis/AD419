CREATE VIEW [dbo].[AccountsUFY]
AS
SELECT        A.Chart, A.Account, O.OrgR, A.Org, A.AccountName, A.IsCAES, A.AnnualReportCode, A.PrincipalInvestigatorName, A.EffectiveDate, A.ExpirationDate, A.MgrId, 
                         A.MgrName, A.PrincipalInvestigatorId, A.Purpose, A.AwardNum, A.AwardEndDate, A.OpFundNum, A.SubFundGroupNum, A.A11AcctNum AS UcAccount, 
                         CASE WHEN A.EffectiveDate <= GETDATE() AND (A.ExpirationDate IS NULL OR
                         A.ExpirationDate >= GETDATE()) THEN 1 ELSE 0 END AS IsActive, A.HigherEdFuncCode
FROM            dbo.Accounts AS A LEFT OUTER JOIN
                         dbo.OrganizationsV AS O ON A.Chart = O.Chart AND A.Org = O.Org AND A.Year = O.Year AND A.Period = O.Period
WHERE        (A.Year = 9999) AND (A.Period = '--')
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsUFY';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'AccountsUFY';

