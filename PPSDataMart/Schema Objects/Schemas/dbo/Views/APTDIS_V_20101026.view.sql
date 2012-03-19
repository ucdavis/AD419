CREATE VIEW [dbo].[APTDIS_V_20101026]
AS
SELECT        EmployeeID, FullName, UCDMailID, HomeDepartment, HireDate, OriginalHireDate, EmployeeStatus, TitleCode, AlternateDepartment, AdministrativeDepartment, 
                         WorkDepartment, SchoolDivision, RepresentedCode, WOSCode, ADCCode, TypeCode, Grade, PersonnelProgram, TitleUnitCode, ApptBeginDate, ApptEndDate, 
                         PaySchedule, LeaveAccrualCode, DOSCode, PayRate, [Percent], FixedVarCode, AcademicBasis, PaidOver, DistNo, ApptNo, DepartmentNo, OrgCode, FTE, PayBegin, 
                         PayEnd, DistPercent, DistPayRate, RateCode, Step, Chart, Account, SubAccount, Object, SubObject, Project, OPFund
FROM            dbo.PerAptDis_V
WHERE        (PayBegin IN
                             (SELECT        MAX(PayBegin) AS Expr1
                               FROM            dbo.PerAptDis_V AS apd
                               WHERE        (dbo.PerAptDis_V.EmployeeID = EmployeeID)))



