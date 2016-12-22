CREATE VIEW dbo.NewAllProjectsImportV
AS
SELECT        AccessionNumber, ProjectNumber, ProposalNumber, AwardNumber, Title, OrganizationName, 
                         CASE WHEN IsUCD = 1 THEN CASE WHEN OrgR = 'XXXX' THEN OrgR WHEN Dept1 IS NULL AND OrgR IS NULL AND SUBSTRING(ProjectNumber, 6, 3) 
                         = 'IPO' THEN 'AIND' ELSE ISNULL(Dept1, OrgR) END ELSE NULL END AS OrgR, Department, ProjectDirector, CoProjectDirectors, FundingSource, ProjectStartDate, 
                         ProjectEndDate, ProjectStatus, IsUCD, NULL AS IsExpired, CASE WHEN RIGHT(RTRIM(ProjectNumber), 2) IN ('CG', 'OG', 'SG') THEN 1 ELSE 0 END AS Is204, 
                         CASE WHEN ProjectNumber LIKE '%XXX%' THEN 1 ELSE 0 END AS IsInterdepartmental
FROM            (SELECT        CASE WHEN [Department] LIKE 'Ag%%Resource%Econ%' THEN 'AARE' WHEN [Department] LIKE 'Animal%Sci%' THEN 'AANS' WHEN [Department] LIKE 'Bio%Ag%En%'
                                                     THEN 'ABAE' WHEN [Department] LIKE '%Land%Air%Water%Resour%' THEN 'ALAW' WHEN [Department] LIKE 'Entomology%Nematology%' THEN 'AENM'
                                                     WHEN [Department] LIKE 'Env%Science%Policy%' THEN 'ADES' WHEN [Department] LIKE 'Env%Tox%' THEN 'AETX' WHEN [Department] LIKE 'Evolution%Ecology%'
                                                     THEN 'BEVE' WHEN [Department] LIKE 'Food%Science%Tech%' THEN 'AFST' WHEN [Department] LIKE 'Human%Ecology%' THEN 'AHCE' WHEN [Department]
                                                     LIKE 'Independent%' THEN 'AIND' WHEN [Department] LIKE 'Interdepartmental%' THEN 'XXXX' WHEN [Department] LIKE 'Micro%Molecular%Gen%' THEN
                                                     'BMIC' WHEN [Department] LIKE 'Molecular%Cell%Bio%' THEN 'BMCB' WHEN [Department] LIKE 'Neurobio%Physiology%Behavior%' THEN 'BNPB' WHEN
                                                     [Department] LIKE 'Nutrition%' THEN 'ANUT' WHEN [Department] LIKE 'Plant%Bio%' THEN 'BPLB' WHEN [Department] LIKE 'Plant%Path%' THEN 'APPA' WHEN
                                                     [Department] LIKE 'Plant%Sci%' THEN 'APLS' WHEN [Department] LIKE 'Textiles%Clothing%' THEN 'ATXC' WHEN [Department] LIKE 'Vit%Enology%' THEN
                                                     'AVIT' WHEN [Department] LIKE 'Wildlife%Fish%Cons%Bio%' THEN 'AWFC' END AS Dept1, CASE WHEN [ReportingOrg].OrgR IS NULL 
                                                    THEN CASE WHEN SUBSTRING([AllProjectsImport].ProjectNumber, 6, 3) = 'XXX' THEN 'XXXX' END ELSE [ReportingOrg].OrgR END AS OrgR, 
                                                    dbo.AllProjectsImport.AccessionNumber, dbo.AllProjectsImport.ProjectNumber, dbo.AllProjectsImport.ProposalNumber, 
                                                    dbo.AllProjectsImport.AwardNumber, dbo.AllProjectsImport.Title, dbo.AllProjectsImport.OrganizationName, dbo.AllProjectsImport.Department, 
                                                    dbo.AllProjectsImport.ProjectDirector, dbo.AllProjectsImport.CoProjectDirectors, dbo.AllProjectsImport.FundingSource, 
                                                    dbo.AllProjectsImport.ProjectStartDate, dbo.AllProjectsImport.ProjectEndDate, dbo.AllProjectsImport.ProjectStatus, 
                                                    CASE WHEN OrganizationName LIKE 'SAES - UNIVERSITY OF CALIFORNIA AT DAVIS%' THEN 1 ELSE 0 END AS IsUCD
                          FROM            dbo.AllProjectsImport LEFT OUTER JOIN
                                                    dbo.ReportingOrg ON SUBSTRING(dbo.AllProjectsImport.ProjectNumber, 6, 3) = dbo.ReportingOrg.OrgCd3Char AND dbo.ReportingOrg.IsActive = 1) AS t1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'NewAllProjectsImportV';


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
         Begin Table = "t1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 227
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
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'NewAllProjectsImportV';

