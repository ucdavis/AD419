CREATE VIEW dbo.ProjectImportV
AS
SELECT        AccessionNumber, ProjectNumber, ProposalNumber, AwardNumber, Title, OrganizationName, 
                         CASE WHEN IsUCD = 1 THEN CASE WHEN OrgR = 'XXXX' THEN OrgR WHEN Dept1 IS NULL AND OrgR IS NULL AND SUBSTRING(ProjectNumber, 6, 3) 
                         = 'IPO' THEN 'AIND' ELSE ISNULL(Dept1, OrgR) END ELSE NULL END AS OrgR, Department, ProjectDirector, CoProjectDirectors, FundingSource, ProjectStartDate, 
                         ProjectEndDate, ProjectStatus, IsUCD
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
                                                    dbo.ReportingOrg ON SUBSTRING(dbo.AllProjectsImport.ProjectNumber, 6, 3) = dbo.ReportingOrg.OrgCd3Char AND dbo.ReportingOrg.IsActive = 1
                          WHERE        (dbo.AllProjectsImport.ProjectEndDate >= CONVERT(DateTime, '2014-06-30 00:00:00.000')) AND 
                                                    (dbo.AllProjectsImport.ProjectStartDate < CONVERT(DateTime, '2015-10-01 00:00:00.000'))) AS t1