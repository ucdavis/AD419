
CREATE VIEW [dbo].[UFYOrganizationsOrgR_v]
AS
SELECT        Chart, Org, OrgR, BeginDate, EndDate
FROM            (SELECT        Chart, Org, 
	CASE 
		WHEN (TYPE IN ('G', 'N')) THEN NULL 
		WHEN (Org4 = 'BIOS' AND Org5 <> 'CBSD') THEN Chart5 
		WHEN Org4 = 'VETM' THEN Chart5 
		ELSE Chart6 END AS ChartR, 
                                                    
	CASE 
		WHEN (TYPE IN ('G', 'N')) THEN NULL 
		WHEN (Org4 = 'BIOS' AND Org5 <> 'CBSD') THEN Org5 
		WHEN Org4 = 'VETM' THEN Org5
		ELSE Org6 END AS OrgR, 
		
	CASE 
		WHEN (TYPE IN ('G', 'N')) THEN NULL 
		WHEN (Org4 = 'BIOS' AND Org5 <> 'CBSD') THEN Name5 
		WHEN Org4 = 'VETM' THEN Name5
		ELSE Name6 END AS NameR, BeginDate, EndDate

                          FROM           [FISDataMart].[dbo].[Organizations]
                          WHERE        (Year = '9999') AND (Period = '--') AND (Type NOT IN ('G', 'N', 'S'))) AS t1
GO



GO


