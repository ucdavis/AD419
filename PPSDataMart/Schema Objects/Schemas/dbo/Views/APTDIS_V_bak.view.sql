CREATE VIEW [dbo].[APTDIS_V_bak]
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
WHERE        (dbo.Distributions.PayBegin <= GETDATE()) AND (dbo.Distributions.PayEnd >= GETDATE() OR
                         dbo.Distributions.PayEnd IS NULL) AND (dbo.Persons.IsInPPS = 1) AND (dbo.Persons.EmployeeStatus <> 'S') AND (dbo.Distributions.IsInPPS = 1) AND 
                         (dbo.Appointments.IsInPPS = 1)

