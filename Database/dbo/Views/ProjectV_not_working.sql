CREATE VIEW dbo.[ProjectV_not_working]
AS
SELECT        TOP (100) PERCENT t1.AccessionNumber AS Accession, t1.ProjectNumber AS Project, t1.IsInterdepartmental, CONVERT(bit, 
                         CASE WHEN [IsIgnored] = 1 THEN 0 ELSE 1 END) AS isValid, t1.ProjectStartDate AS BeginDate, t1.ProjectEndDate AS TermDate, NULL AS ProjTypeCd, NULL 
                         AS RegionalProjNum, t1.OrgR, t8.CRISDeptCd AS CRIS_DeptID, t1.AwardNumber AS CSREES_ContractNo, CASE WHEN RTRIM([ProjectStatus]) 
                         LIKE 'Complete Without Final Report' THEN 'B' ELSE LEFT(RTRIM([ProjectStatus]), 1) END AS StatusCd, t1.Title, NULL AS UpdateDate, t1.ProjectDirector AS inv1, 
                         t2.Name AS inv2, t3.Name AS Inv3, t4.Name AS inv4, t5.Name AS inv5, t6.Name AS inv6, t7.Name AS inv7, t1.Is204, t1.Id AS idProject
FROM            dbo.AllProjectsNew AS t1 LEFT OUTER JOIN
                         dbo.PrincipalInvestigatorsPerProjectV AS t2 ON t1.Id = t2.ProjectId AND t2.InvNum = 1 LEFT OUTER JOIN
                         dbo.PrincipalInvestigatorsPerProjectV AS t3 ON t1.Id = t3.ProjectId AND t3.InvNum = 2 LEFT OUTER JOIN
                         dbo.PrincipalInvestigatorsPerProjectV AS t4 ON t1.Id = t4.ProjectId AND t4.InvNum = 3 LEFT OUTER JOIN
                         dbo.PrincipalInvestigatorsPerProjectV AS t5 ON t1.Id = t5.ProjectId AND t5.InvNum = 4 LEFT OUTER JOIN
                         dbo.PrincipalInvestigatorsPerProjectV AS t6 ON t1.Id = t6.ProjectId AND t6.InvNum = 5 LEFT OUTER JOIN
                         dbo.PrincipalInvestigatorsPerProjectV AS t7 ON t1.Id = t7.ProjectId AND t7.InvNum = 6 LEFT OUTER JOIN
                         dbo.ReportingOrg AS t8 ON t1.OrgR = t8.OrgR AND (t8.IsActive = 1 OR
                         t8.OrgR IN ('XXXX', 'AINT'))
WHERE        (t1.IsUCD = 1) AND (t1.IsExpired = 0) AND (t1.AccessionNumber NOT LIKE '0000000') AND (t1.IsIgnored = 0 OR
                         t1.IsIgnored IS NULL) AND (RTRIM(t1.ProjectStatus) NOT LIKE 'Draft') AND (RTRIM(t1.ProjectStatus) NOT LIKE 'Unknown')
ORDER BY Accession