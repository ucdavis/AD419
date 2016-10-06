CREATE VIEW dbo.AD419CurrentProjectListV
AS
SELECT        ProjectNew.AccessionNumber, ProjectNew.ProjectNumber, ProjectNew.ProposalNumber, ProjectNew.AwardNumber, ProjectNew.Title, ProjectNew.OrganizationName, 
                         ProjectNew.OrgR, ProjectNew.Department, ProjectNew.ProjectDirector, ProjectNew.CoProjectDirectors, ProjectNew.FundingSource, ProjectNew.ProjectStartDate, 
                         ProjectNew.ProjectEndDate, ProjectNew.ProjectStatus, ProjectNew.IsInterdepartmental, ProjectNew.IsIgnored ^ 1 AS IsAssociable
FROM            dbo.AllProjectsNew AS ProjectNew INNER JOIN
                         dbo.CurrentFiscalYear AS t2 ON ProjectNew.ProjectEndDate >= CONVERT(DateTime, CONVERT(varchar(4), t2.FiscalYear - 1) + '-03-01 00:00:00.000') AND 
                         ProjectNew.ProjectStartDate < CONVERT(DateTime, CONVERT(varchar(4), t2.FiscalYear) + '-10-01 00:00:00.000') LEFT OUTER JOIN
                         dbo.ReportingOrg AS t8 ON ProjectNew.OrgR = t8.OrgR AND (t8.IsActive = 1 OR
                         t8.OrgR IN ('XXXX', 'AINT'))
WHERE        (ProjectNew.IsUCD = 1) AND (ProjectNew.IsExpired = 0) AND (ProjectNew.AccessionNumber NOT LIKE '0000000') AND (RTRIM(ProjectNew.ProjectStatus) 
                         NOT LIKE 'Draft') AND (RTRIM(ProjectNew.ProjectStatus) NOT LIKE 'Unknown')