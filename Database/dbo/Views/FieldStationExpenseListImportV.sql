/* revised SQL for FieldStationExpenseListImportV without join to orgXOrgR since OrgR is now present in Project view.*/
CREATE VIEW dbo.FieldStationExpenseListImportV
AS
SELECT        t1.ProjectAccessionNum AS Accession, t1.FieldStationCharge, t2.inv1 AS Project_Leader, 
                         CASE WHEN t2.IsInterdepartmental = 1 THEN 'XXXX' ELSE OrgR END AS Org_R
FROM            dbo.FieldStationExpenseListImport AS t1 LEFT OUTER JOIN
                         dbo.Project AS t2 ON t1.ProjectAccessionNum = t2.Accession
GROUP BY t1.Id, t1.ProjectAccessionNum, t1.FieldStationCharge, t2.inv1, CASE WHEN t2.IsInterdepartmental = 1 THEN 'XXXX' ELSE OrgR END