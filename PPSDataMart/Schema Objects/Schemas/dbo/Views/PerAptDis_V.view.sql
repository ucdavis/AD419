

CREATE VIEW [dbo].[PerAptDis_V]
AS
SELECT        dbo.Persons.EmployeeID, dbo.Persons.FullName, dbo.Persons.UCDMailID, dbo.Persons.HomeDepartment, dbo.Persons.HireDate, dbo.Persons.OriginalHireDate, 
                         dbo.Persons.EmployeeStatus, dbo.Appointments.TitleCode, dbo.Persons.AlternateDepartment, dbo.Persons.AdministrativeDepartment, 
                         CASE ISNULL(AlternateDepartment, 0) WHEN 0 THEN AdministrativeDepartment ELSE AlternateDepartment END AS WorkDepartment, dbo.Persons.SchoolDivision, 
                         dbo.Appointments.RepresentedCode, dbo.Appointments.WOSCode, dbo.Distributions.ADCCode, dbo.Appointments.TypeCode, dbo.Appointments.Grade, 
                         dbo.Appointments.PersonnelProgram, dbo.Appointments.TitleUnitCode, dbo.Appointments.BeginDate AS ApptBeginDate, dbo.Appointments.EndDate AS ApptEndDate, 
                         dbo.Appointments.PaySchedule, dbo.Appointments.LeaveAccrualCode, dbo.Distributions.DOSCode, dbo.Appointments.PayRate, dbo.Appointments.[Percent], 
                         dbo.Appointments.FixedVarCode, dbo.Appointments.AcademicBasis, dbo.Appointments.PaidOver, dbo.Distributions.DistNo, dbo.Distributions.ApptNo, 
                         dbo.Distributions.DepartmentNo, dbo.Distributions.OrgCode, dbo.Distributions.FTE, dbo.Distributions.PayBegin, dbo.Distributions.PayEnd, 
                         dbo.Distributions.[Percent] AS DistPercent, dbo.Distributions.PayRate AS DistPayRate, dbo.Appointments.RateCode, dbo.Distributions.Step, dbo.Distributions.Chart, 
                         dbo.Distributions.Account, dbo.Distributions.SubAccount, dbo.Distributions.Object, dbo.Distributions.SubObject, dbo.Distributions.Project, 
                         dbo.Distributions.OPFund
FROM            dbo.Appointments INNER JOIN
                         dbo.Distributions ON dbo.Appointments.EmployeeID = dbo.Distributions.EmployeeID INNER JOIN
                         dbo.Persons ON dbo.Appointments.EmployeeID = dbo.Persons.EmployeeID
WHERE        (dbo.Appointments.BeginDate <= GETDATE()) AND (dbo.Appointments.EndDate >= GETDATE() OR
                         dbo.Appointments.EndDate IS NULL) AND (dbo.Distributions.PayBegin <= GETDATE()) AND (dbo.Persons.IsInPPS = 1) AND (dbo.Persons.EmployeeStatus <> 'S') AND 
                         (dbo.Distributions.IsInPPS = 1) AND (dbo.Appointments.IsInPPS = 1)



GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 1, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'PerAptDis_V';


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
         Begin Table = "Appointments"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 225
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Distributions"
            Begin Extent = 
               Top = 6
               Left = 263
               Bottom = 135
               Right = 486
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Persons"
            Begin Extent = 
               Top = 6
               Left = 524
               Bottom = 135
               Right = 753
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
      Begin ColumnWidths = 9
         Width = 284
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'PerAptDis_V';

