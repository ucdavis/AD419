CREATE VIEW [dbo].[APTDIS_V]
AS
SELECT        EmployeeID, FullName, UCDMailID, HomeDepartment, HireDate, OriginalHireDate, EmployeeStatus, TitleCode, AlternateDepartment, AdministrativeDepartment, 
                         WorkDepartment, SchoolDivision, RepresentedCode, WOSCode, ADCCode, TypeCode, Grade, PersonnelProgram, TitleUnitCode, ApptBeginDate, ApptEndDate, 
                         PaySchedule, LeaveAccrualCode, DOSCode, PayRate, [Percent], FixedVarCode, AcademicBasis, PaidOver, DistNo, ApptNo, DepartmentNo, OrgCode, FTE, PayBegin, 
                         PayEnd, DistPercent, DistPayRate, RateCode, Step, Chart, Account, SubAccount, Object, SubObject, Project, OPFund
FROM            dbo.PerAptDis_V
WHERE        (PayBegin = CASE WHEN (PayEnd >= GETDATE() OR
                         PayEnd IS NULL) THEN
                             (SELECT        MIN(PayBegin) AS Expr1
                               FROM            dbo.PerAptDis_V AS apd
                               WHERE        (dbo.PerAptDis_V.EmployeeID = EmployeeID AND (PayEnd IS NULL OR
                                                         PayEnd >= GETDATE()))) ELSE
                             (SELECT        MAX(PayBegin) AS Expr2
                               FROM            dbo.PerAptDis_V AS apd2
                               WHERE        (dbo.PerAptDis_V.EmployeeID = EmployeeID AND (PayEnd < GETDATE()))) END)

