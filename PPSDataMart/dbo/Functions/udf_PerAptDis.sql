
-- =============================================
-- Author:		Ken Taylor
-- Create date: June 8, 2017
-- Description:	Revision of PerAptDis_V that allows setting of 
-- begin and end date in order to be used for AD-419 past years
--
-- Usage:
/*

USE [PPSDataMart]
GO
SELECT * FROM [dbo].udf_PerAptDis('2015-10-01', '2016-09-30')


USE [PPSDataMart]
GO
SELECT * FROM [dbo].udf_PerAptDis(DEFAULT, DEFAULT)

*/ 
-- Modifications: 
-- 2017-08-03 by kjt: Modified the where clause as it was filtering out employees that had
-- recently had their distribution pay begin and pay end dates updated.  This is because we
-- do not keep a history of past distributions.  
-- Also removed the "S" separated check, as this would filter out employees if we were
-- working on a prior year, as in with AD-419, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_PerAptDis] 
( 
    @PayBeginDate datetime2 = NULL,
	@PayEndDate datetime2 = NULL 
) 
RETURNS 
@PersonApptDistTable TABLE 
( 
	EmployeeID VARCHAR(10),
	FullName VARCHAR(100),
	UCDMailID VARCHAR(32),
	HomeDepartment VARCHAR(6),
	HireDate datetime,
	OriginalHireDate datetime,
	EmployeeStatus CHAR(1),
	TitleCode VARCHAR(4),
	AlternateDepartment VARCHAR(6),
	AdministrativeDepartment VARCHAR(6),
	WorkDepartment VARCHAR(6),
	SchoolDivision VARCHAR(2),
	RepresentedCode CHAR(1),
	WOSCode CHAR(1),
	ADCCode CHAR(1),
	TypeCode CHAR(1),
	Grade CHAR(2),
	PersonnelProgram CHAR(1),
	TitleUnitCode VARCHAR(2),
	ApptBeginDate datetime,
	ApptEndDate datetime,
	PaySchedule VARCHAR(2),
	LeaveAccrualCode CHAR(1),
	DOSCode CHAR(3),
	PayRate DECIMAL(10,4),
	[Percent] DECIMAL(5,4),
	FixedVarCode CHAR(1),
	AcademicBasis CHAR(2),
	PaidOver VARCHAR(2),
	DistNo SMALLINT,
	ApptNo SMALLINT,
	DepartmentNo CHAR(6),
	OrgCode VARCHAR(4),
	FTE DECIMAL(3,2),
	PayBegin datetime,
	PayEnd datetime,
	DistPercent DECIMAL(5,4),
	DistPayRate DECIMAL(9,4),
	RateCode CHAR(1),
	Step VARCHAR(4),
	Chart CHAR(1),
	Account CHAR(7),
	SubAccount VARCHAR(5),
	[Object] VARCHAR(4),
	SubObject VARCHAR(3),
	Project VARCHAR(10),
	OPFund VARCHAR(6) 
) 
AS 
BEGIN
	IF @PayBeginDate IS NULL 
        SELECT @PayBeginDate = GETDATE() 

    IF @PayEndDate IS NULL 
        SELECT @PayEndDate = GETDATE() 

    INSERT
    INTO
        @PersonApptDistTable 
    SELECT
        dbo.Persons.EmployeeID,
        dbo.Persons.FullName,
        dbo.Persons.UCDMailID,
        dbo.Persons.HomeDepartment,
        dbo.Persons.HireDate,
        dbo.Persons.OriginalHireDate,
        dbo.Persons.EmployeeStatus,
        dbo.Appointments.TitleCode,
        dbo.Persons.AlternateDepartment,
        dbo.Persons.AdministrativeDepartment,
        CASE ISNULL(AlternateDepartment, 0) 
            WHEN 0 
            THEN AdministrativeDepartment 
            ELSE AlternateDepartment 
        END                             AS WorkDepartment,
        dbo.Persons.SchoolDivision,
        dbo.Appointments.RepresentedCode,
        dbo.Appointments.WOSCode,
        dbo.Distributions.ADCCode,
        dbo.Appointments.TypeCode,
        dbo.Appointments.Grade,
        dbo.Appointments.PersonnelProgram,
        dbo.Appointments.TitleUnitCode,
        dbo.Appointments.BeginDate  AS ApptBeginDate,
        dbo.Appointments.EndDate    AS ApptEndDate,
        dbo.Appointments.PaySchedule,
        dbo.Appointments.LeaveAccrualCode,
        dbo.Distributions.DOSCode,
        dbo.Appointments.PayRate,
        dbo.Appointments.[Percent],
        dbo.Appointments.FixedVarCode,
        dbo.Appointments.AcademicBasis,
        dbo.Appointments.PaidOver,
        dbo.Distributions.DistNo,
        dbo.Distributions.ApptNo,
        dbo.Distributions.DepartmentNo,
        dbo.Distributions.OrgCode,
        dbo.Distributions.FTE,
        dbo.Distributions.PayBegin,
        dbo.Distributions.PayEnd,
        dbo.Distributions.[Percent] AS DistPercent,
        dbo.Distributions.PayRate   AS DistPayRate,
        dbo.Appointments.RateCode,
        dbo.Distributions.Step,
        dbo.Distributions.Chart,
        dbo.Distributions.Account,
        dbo.Distributions.SubAccount,
        dbo.Distributions.Object,
        dbo.Distributions.SubObject,
        dbo.Distributions.Project,
        dbo.Distributions.OPFund 
    FROM
        dbo.Appointments 
            INNER JOIN dbo.Distributions 
            ON dbo.Appointments.EmployeeID = dbo.Distributions.EmployeeID 
                INNER JOIN dbo.Persons 
                ON dbo.Appointments.EmployeeID = dbo.Persons.EmployeeID 
    WHERE
	
	-- This is the revised WHERE clause I had tested, but it's apparently too slow for ESRA
        (dbo.Persons.IsInPPS = 1) AND
        (dbo.Appointments.BeginDate <= @PayEndDate AND
        (dbo.Appointments.EndDate >= @PayBeginDate OR dbo.Appointments.EndDate IS NULL)) AND
        (dbo.Distributions.PayBegin <= GETDATE() AND  -- @PayEndDate needed to be replaced with GETDATE()
		-- in order to handle updated pay begin and pay end dates, which ended up filtering out
		-- certain records.
        (dbo.Distributions.PayEnd >= @PayBeginDate OR dbo.Distributions.PayEnd IS NULL)) 
        --AND (dbo.Persons.EmployeeStatus <> 'S') -- This won't work if we're looking for prior FFY and the
		-- employee has since been separated. 
	
	---- This is the original WHERE clause taken directly from the dbo.PerAptDis_V view.
	--(dbo.Appointments.BeginDate <= @PayEndDate) AND --GETDATE()) AND
	--(dbo.Appointments.EndDate >=   @PayBeginDate OR --GETDATE() OR
	--dbo.Appointments.EndDate IS NULL) AND
	--(dbo.Distributions.PayBegin <= @PayEndDate) AND --GETDATE()) AND
	--(dbo.Persons.IsInPPS = 1) AND
	--(dbo.Persons.EmployeeStatus <> 'S') AND
	--(dbo.Distributions.IsInPPS = 1) AND
	--(dbo.Appointments.IsInPPS = 1)

    RETURN 
END