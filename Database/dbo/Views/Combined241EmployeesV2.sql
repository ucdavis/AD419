
CREATE VIEW [dbo].[Combined241EmployeesV2]
AS
SELECT        EID, OrgR, ProjectOrgR, Accession, CASE WHEN OrgR != ProjectOrgR OR
                         ProjectOrgR IS NULL THEN 1 ELSE 0 END AS IsProrated
FROM            (SELECT DISTINCT 
                                                    t1_1.EID, t1_1.OrgR, CASE WHEN t4.IsInterdepartmental = 1 THEN t1_1.OrgR WHEN t3.OrgR = 'AINT' AND t1_1.OrgR = t4.OrgR THEN t1_1.OrgR ELSE t3.OrgR END AS ProjectOrgR, t4.Accession
                          FROM            (SELECT DISTINCT LEFT(REPLACE(PEV.Employee_Name, '.', ''), CHARINDEX(',', REPLACE(PEV.Employee_Name, '.', ''), 1) + 1) AS employee_name, PEV.EID, PEV.OrgR
                                                    FROM            dbo.Expenses AS PEV INNER JOIN
                                                                              dbo.Expenses AS PEV2 ON PEV.EID = PEV2.EID AND PEV2.FTE_SFN = '241'
                                                    WHERE        (PEV.OrgR NOT IN
                                                                                  (SELECT        OrgR
                                                                                    FROM            dbo.udf_GetOrgRExclusions() AS udf_GetOrgRExclusions_3))
                                                    GROUP BY PEV.EID, REPLACE(PEV.Employee_Name, '.', ''), PEV.OrgR
                                                    UNION
                                                    SELECT DISTINCT LEFT(REPLACE(PI, '.', ''), CHARINDEX(',', REPLACE(PI, '.', ''), 1) + 1) AS employee_name, EmployeeID AS EID, OrgR
                                                    FROM            dbo.ProjectPI AS t2) AS t1_1 LEFT OUTER JOIN
                                                    dbo.ProjectPI AS t3 ON t1_1.EID = t3.EmployeeID LEFT OUTER JOIN
                                                    dbo.PI_OrgR_Accession AS t4 ON t3.EmployeeID = t4.EmployeeID
                          WHERE        (t1_1.OrgR NOT LIKE 'AINT')) AS t1
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Combined241EmployeesV2';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "t1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'Combined241EmployeesV2';

