
CREATE VIEW [dbo].[UCP_PersonsV]
AS
SELECT DISTINCT 
                         t1.NAME AS FullName, COALESCE (t1.EMP_ID, t1.PPS_ID) AS EmployeeID, t1.FIRST_NAME AS FirstName, t1.MIDDLE_NAME AS MiddleName, t1.LAST_NAME AS LastName, t1.NAME_SUFFIX AS Suffix, t1.BIRTHDATE, 
                         t1.EMAIL AS UCDMailID, t1.UCD_LOGIN_ID AS UCDLoginID, t1.JOB_DEPT AS HomeDepartment, CASE WHEN JOB_DEPT = HomeDept THEN AltDept1 ELSE AltDept2 END AS AlternateDepartment, 
                         CASE WHEN JOB_DEPT = HomeDept THEN AltDept2 ELSE AltDept3 END AS AdministrativeDepartment, t1.[SCH/DIV] AS SchoolDivision, RIGHT(t1.JOBCODE, 4) AS PrimaryTitle, t1.POSN_NBR AS PrimaryApptNo, 
                         t1.EMP_RCD AS PrimaryDistNo, t1.CTO AS JobGroupID, t1.HIRE_DT AS HireDate, t1.EMP_ORIG_HIRE_DT AS OriginalHireDate, t1.EMP_STAT AS EmployeeStatus, t1.STDT_FLG AS StudentStatus, 
                         t1.EMP_HIGH_EDU_LVL_CD AS EducationLevel, t1.UNION_CD AS BarganingUnit, t1.LEAVE_SERVICE_CREDIT AS LeaveServiceCredit, t1.SUPERVISOR, t1.EFF_DT AS LastChangeDate, 1 AS IsInPPS, t1.PPS_ID, 
                         t1.EMP_ID AS UCP_EMPLID, CASE WHEN EMP_ID IS NOT NULL THEN 1 ELSE 0 END AS HasUcpEmplId
FROM           dbo.UCPath_PersonJob AS t1 LEFT OUTER JOIN
                         dbo.UCPath_JobDepartmentPrecidence AS t2 ON t1.EMP_ID = t2.EMPLID
WHERE        (t1.JOB_IND = 'P')
GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'UCP_PersonsV';


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
               Bottom = 291
               Right = 272
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "t2"
            Begin Extent = 
               Top = 6
               Left = 310
               Bottom = 136
               Right = 480
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
      Begin ColumnWidths = 31
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'UCP_PersonsV';

