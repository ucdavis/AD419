CREATE VIEW [dbo].[OrganizationsV]
AS
SELECT DISTINCT 
                        Year, Period, Org, Chart, [Level], Name, Type, BeginDate, EndDate, HomeDeptNum, HomeDeptName, UpdateDate, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN CHART2 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN CHART5 
							WHEN CHART1 = '3' THEN Chart1 
							ELSE CHART4 END) AS Chart1, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN ORG2 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN ORG5 
							WHEN CHART1 = '3' THEN Org1 
							ELSE ORG4 END) AS Org1, 
						(	
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name2
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name5 
							WHEN CHART1 = '3' THEN Name1 
							ELSE Name4 END) AS Name1, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart3 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart6 
							WHEN CHART1 = '3' THEN Chart2 ELSE Chart5 END) AS Chart2, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org3 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org6 
							WHEN CHART1 = '3' THEN Org2 
							ELSE Org5 END) AS Org2, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name3 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name6 
							WHEN CHART1 = '3' THEN Name2 
							ELSE Name5 END) AS Name2, 
						ISNULL(
						(
							CASE WHEN (Org1 = 'BIOS') THEN Chart2 
							WHEN (Org4 = 'BIOS') THEN Chart5 
							WHEN (CHART = '3' AND Org1 = 'AAES') THEN Chart3 
							WHEN (CHART = 'L' AND Org2 = 'AAES') THEN Chart4 
							WHEN (Org4 = 'AAES') THEN Chart6 
							WHEN (CHART = 'L' AND Org5 = 'AAES') THEN Chart7 
							WHEN (Org1 = 'VETM') THEN Chart2 
							WHEN (Org4 = 'VETM') THEN Chart5 END), Chart) AS ChartR, 
						ISNULL(
						(
							CASE WHEN (Org1 = 'BIOS') THEN Org2 
							WHEN (Org4 = 'BIOS') THEN Org5 
							WHEN (CHART = '3' AND Org1 = 'AAES') THEN Org3 
							WHEN (CHART = 'L' AND Org2 = 'AAES') THEN Org4 
							WHEN (Org4 = 'AAES') THEN Org6 
							WHEN (CHART = 'L' AND Org5 = 'AAES') THEN Org7
							WHEN (Org1 = 'VETM') THEN Org2 
							WHEN (Org4 = 'VETM') THEN Org5 END), Org) AS OrgR, 
						ISNULL(
						(
							CASE WHEN (Org1 = 'BIOS') THEN Name2 
							WHEN (Org4 = 'BIOS') THEN Name5 
							WHEN (CHART = '3' AND Org1 = 'AAES') THEN Name3 
							WHEN (CHART = 'L' AND Org2 = 'AAES') THEN Name4 
							WHEN (Org4 = 'AAES') THEN Name6 
							WHEN (CHART = 'L' AND Org5 = 'AAES') THEN Name7 
							WHEN (Org1 = 'VETM') THEN Name2 
							WHEN (Org4 = 'VETM') THEN Name5 END), Name) AS NameR, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart4
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart7 
							WHEN Org4 = 'VETM' THEN Chart5
							WHEN CHART1 = '3' THEN Chart3 
							ELSE Chart6 END) AS Chart3, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org4 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org7
							WHEN Org4 = 'VETM' THEN Org5 
							WHEN CHART1 = '3' THEN Org3 
							ELSE Org6 END) AS Org3,
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name4 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name7 
							WHEN Org4 = 'VETM' THEN Name5
							WHEN CHART1 = '3' THEN Name3 
							ELSE Name6 END) AS Name3, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart5
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart8 
							WHEN Org4 = 'VETM' THEN Chart6
							WHEN CHART1 = '3' THEN Chart4 
							ELSE Chart7 END) AS Chart4, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org5 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org8 
							WHEN Org4 = 'VETM' THEN Org6
							WHEN CHART1 = '3' THEN Org4 ELSE Org7 END) AS Org4, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name5 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name8 
							WHEN Org4 = 'VETM' THEN Name6
							WHEN CHART1 = '3' THEN Name4 
							ELSE Name7 END) AS Name4, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart6 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart9 
							WHEN Org4 = 'VETM' THEN Chart7
							WHEN CHART1 = '3' THEN Chart5 
							ELSE Chart8 END) AS Chart5, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org6 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org9
							WHEN Org4 = 'VETM' THEN Org7
							WHEN CHART1 = '3' THEN Org5 
							ELSE Org8 END) AS Org5, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name6 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name9
							WHEN Org4 = 'VETM' THEN Name7
							WHEN CHART1 = '3' THEN Name5 
							ELSE Name8 END) AS Name5, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart7 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart10 
							WHEN Org4 = 'VETM' THEN Chart8
							WHEN CHART1 = '3' THEN Chart6 
							ELSE Chart9 END) AS Chart6, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org7 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org10 
							WHEN Org4 = 'VETM' THEN Org8
							WHEN CHART1 = '3' THEN Org6 
							ELSE Org9 END) AS Org6, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name7 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name10 
							WHEN Org4 = 'VETM' THEN Name8
							WHEN CHART1 = '3' THEN Name6 
							ELSE Name9 END) AS Name6, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart8 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart11
							WHEN Org4 = 'VETM' THEN Chart9 
							WHEN CHART1 = '3' THEN Chart7 
							ELSE Chart10 END) AS Chart7, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org8 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org11 
							WHEN Org4 = 'VETM' THEN Org9 
							WHEN CHART1 = '3' THEN Org7 
							ELSE Org10 END) AS Org7, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name8 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name11 
							WHEN Org4 = 'VETM' THEN Name9 
							WHEN CHART1 = '3' THEN Name7 
							ELSE Name10 END) AS Name7, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Chart9 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Chart12 
							WHEN Org4 = 'VETM' THEN Chart10 
							WHEN CHART1 = '3' THEN Chart8 
							ELSE Chart11 END) AS Chart8, 
                        (
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Org9 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Org12 
							WHEN Org4 = 'VETM' THEN Org10 
							WHEN CHART1 = '3' THEN Org8 
							ELSE Org11 END) AS Org8, 
						(
							CASE WHEN CHART1 = 'L' AND ORG1 = 'DANR' THEN Name9 
							WHEN CHART4 = 'L' AND ORG4 = 'DANR' THEN Name12 
							WHEN Org4 = 'VETM' THEN Name10 
							WHEN CHART1 = '3' THEN Name8 
							ELSE Name11 END) AS Name8, 
							
						 ActiveIndicator, OrganizationPK, 
						(
							CASE WHEN (
								(Chart = '3' AND Org5 = 'ACBS') OR
								(Chart = '3' AND Org2 = 'ACBS')) THEN 2 WHEN ((Org4 = 'AAES') OR
								(Chart = 'L' AND Org5 = 'AAES') OR
								(Chart = '3' AND Org1 = 'AAES') OR
								(Chart = 'L' AND Org2 = 'AAES')) THEN 1 
							ELSE 0 END) AS IsCAES
FROM            dbo.Organizations

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OrganizationsV: A view of the organizations table that attempts to the "normalize" the changes made by Kuali and ACBS.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'OrganizationsV';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfigurat', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'OrganizationsV';




GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = N'1', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'OrganizationsV';



