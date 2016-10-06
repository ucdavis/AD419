CREATE VIEW dbo.UFYOrganizationsOrgR_v
AS
SELECT        t1.Chart, t1.Org, COALESCE (t2.AD419OrgR, t1.OrgR) AS OrgR, t1.BeginDate, t1.EndDate
FROM            (SELECT        Chart, Org, CASE WHEN (TYPE IN ('G', 'N')) THEN NULL WHEN (Org4 = 'BIOS' AND Org5 <> 'CBSD') THEN Chart5 ELSE Chart6 END AS ChartR, 
                                                    CASE WHEN (TYPE IN ('G', 'N')) THEN NULL WHEN (Org4 = 'BIOS' AND Org5 <> 'CBSD') THEN Org5 ELSE Org6 END AS OrgR, CASE WHEN (TYPE IN ('G',
                                                     'N')) THEN NULL WHEN (Org4 = 'BIOS' AND Org5 <> 'CBSD') THEN Name5 ELSE Name6 END AS NameR, BeginDate, EndDate
                          FROM            FISDataMart.dbo.Organizations
                          WHERE        (Year = '9999') AND (Period = '--') AND (Type NOT IN ('G', 'N', 'S'))) AS t1 LEFT OUTER JOIN
                         dbo.ExpenseOrgR_X_AD419OrgR AS t2 ON t1.OrgR = t2.ExpenseOrgR AND t1.Chart = t2.Chart