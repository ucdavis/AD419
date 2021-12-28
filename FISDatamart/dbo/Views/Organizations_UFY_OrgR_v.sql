CREATE VIEW [dbo].[Organizations_UFY_OrgR_v]
AS
SELECT        Chart, Org, OrgR, [Type], BeginDate, EndDate
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
		ELSE Name6 END AS NameR, [Type], BeginDate, EndDate

                          FROM           [dbo].[Organizations_UFY]
                          WHERE        (Year = '9999') AND (Period = '--') AND (Type NOT IN ('G', 'N', 'S'))) AS t1