CREATE VIEW dbo.Expenses_Field_Stations
AS
SELECT        t1_2.Accession, t1_2.Project_Leader, t2.OrgR AS Org_R, t1_2.Expense
FROM            (SELECT        Accession, Project_Leader, Expenses / COUNT(*) AS Expense
                          FROM            (SELECT        t1.Accession, t1.Project_Leader, SUM(t1.FieldStationCharge) AS Expenses, t2.OrgR
                                                    FROM            dbo.FieldStationExpenseListImportV AS t1 INNER JOIN
                                                                              dbo.ProjXOrgR AS t2 ON t1.Accession = t2.Accession
                                                    WHERE        (t1.Org_R = 'XXXX')
                                                    GROUP BY t1.Accession, t2.OrgR, t1.Project_Leader) AS t1_1
                          GROUP BY Accession, Project_Leader, Expenses) AS t1_2 INNER JOIN
                         dbo.ProjXOrgR AS t2 ON t1_2.Accession = t2.Accession

UNION

SELECT t1.Accession, t1.Project_Leader, t2.OrgR, SUM(t1.FieldStationCharge) AS Expense
FROM            dbo.FieldStationExpenseListImportV AS t1 INNER JOIN
                dbo.ProjXOrgR AS t2 ON t1.Accession = t2.Accession
WHERE        t1.Org_R <> 'XXXX'
GROUP BY t1.Accession, OrgR, Project_Leader