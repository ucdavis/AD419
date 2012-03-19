CREATE VIEW [dbo].[AdminClusteredDepartmentsV]
AS
SELECT        TOP (100) PERCENT t1.AdminClusterNo, t2.Name AS AdminClusterName, t1.HomeDeptNo, t1.Name, t1.Abbreviation, t1.SchoolCode, t1.MailCode, 
                         t1.HomeOrgUnitCode, t1.LastActionDate
FROM            dbo.Departments AS t1 INNER JOIN
                         dbo.Departments AS t2 ON t1.AdminClusterNo = t2.HomeDeptNo
WHERE        (t1.AdminClusterNo IS NOT NULL)
GROUP BY t1.AdminClusterNo, t1.HomeDeptNo, t1.Name, t1.Abbreviation, t1.SchoolCode, t2.Name, t1.MailCode, t1.HomeOrgUnitCode, t1.LastActionDate
ORDER BY AdminClusterName, t1.AdminClusterNo, t1.HomeDeptNo, t1.Name, t1.Abbreviation, t1.SchoolCode, t1.MailCode, t1.HomeOrgUnitCode, t1.LastActionDate

