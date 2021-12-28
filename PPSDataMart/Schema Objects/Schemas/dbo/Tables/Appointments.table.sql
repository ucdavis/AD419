CREATE TABLE [dbo].[Appointments] (
    [EmployeeID]       CHAR (9)        NOT NULL,
    [ApptNo]           SMALLINT        NOT NULL,
    [Grade]            CHAR (2)        NULL,
    [Department]       CHAR (6)        NULL,
    [TitleCode]        VARCHAR (50)    NULL,
    [TitleUnitCode]    VARCHAR (2)     NULL,
    [AcademicBasis]    CHAR (2)        NULL,
    [PaidOver]         VARCHAR (2)     NULL,
    [RetirementCode]   CHAR (1)        NULL,
    [FixedVarCode]     CHAR (1)        NULL,
    [TypeCode]         CHAR (1)        NULL,
    [ADCCode]          CHAR (1)        NULL,
    [WOSCode]          CHAR (1)        NULL,
    [PersonnelProgram] CHAR (1)        NULL,
    [TimeReportCode]   CHAR (1)        NULL,
    [LeaveAccrualCode] CHAR (1)        NULL,
    [RepresentedCode]  CHAR (1)        NULL,
    [Percent]          DECIMAL (3, 2)  NULL,
    [PayRate]          DECIMAL (10, 4) NULL,
    [PaySchedule]      VARCHAR (2)     NULL,
    [RateCode]         CHAR (1)        NULL,
    [BeginDate]        DATETIME        NULL,
    [EndDate]          DATETIME        NULL,
    [Duration]         VARCHAR (1)     NULL,
    [IsInPPS]          BIT             NULL,
    CONSTRAINT [PK_Appointments] PRIMARY KEY CLUSTERED ([EmployeeID] ASC, [ApptNo] ASC)
);




GO
CREATE NONCLUSTERED INDEX [Appointments_TypeCode_IDX]
    ON [dbo].[Appointments]([TypeCode] ASC);


GO
CREATE NONCLUSTERED INDEX [Appointments_TitleUnitCode_IDX]
    ON [dbo].[Appointments]([TitleUnitCode] ASC);


GO
CREATE NONCLUSTERED INDEX [Appointments_RateCode_IDX]
    ON [dbo].[Appointments]([RateCode] ASC);


GO
CREATE NONCLUSTERED INDEX [Appointments_PayRate_IDX]
    ON [dbo].[Appointments]([PayRate] ASC);


GO
CREATE NONCLUSTERED INDEX [Appointments_Grade_IDX]
    ON [dbo].[Appointments]([Grade] ASC);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'The percentage of time and salary at which an employee is appointed to work at a particular job title for a range of dates within a given department. The appointment end date may be specified or indefinite. The entity includes job title, bargaining unit, percentage of time, beginning and ending dates and annualized salary information. The data originates from the Employee Data Base (EDB) and contains recently-expired, current and future appointments.

Although the business rule is that an appointment must be funded through one or more associated distributions, there is no data validation that removes appointments whose distributions have ended or no longer exist. The home department code at the appointment level is also not validated and is not generally used. The home department code at the appointment level is originally derived from the first or largest percentage of time active distribution-level home department which is itself derived from the related org that the account is associated with in DaFIS.

The data warehouse update process compares the records in the local copy of the data base with the copy of the EDBAPP table at UCOP. Records that are found to be different (added, changed or deleted) are flagged with the appropriate action code (A=add, C=change, D=deleted) and the date in the two UCD-created fields: UCD_ADC_CODE and UCD_ADC_DATE. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment without salary flag: The code indicating whether an appointment is without salary. (values are Y=yes, without salary or N=no, not without salary) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'WOSCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment type code: The code indicating the type of appointment. (values are 1=contract, 2=regular/career, 3=limited (formerly casual), 4=casual/restricted - students, 5=academic, 6=per diem, or 7=regular/career partial year, 8=floater) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'TypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Title/Bargaining unit code: The code indicating the collective bargaining unit to which a title code belongs. (translation in PAYROLL.DVTBUT table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'TitleUnitCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Title code: The code indicating the position classification associated with an appointment. (translation in Titles table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'TitleCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Time reporting code: The code indicating the method for reporting time worked in an appointment. (values are A=positive time by fau, P=positive by dept, S=positive by special timesheet, C=postive by dept, special, N=positive, timesheet not required, Z=positive by on-line, R=exception time by on-line, T=exception by fau, L=exception by dept - for leave accounting usage), E=exception, timesheet not required, W=without salary, no timesheet, Blank=none of the above) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'TimeReportCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Retirement code: The code indicating whether an appointment is eligible for special retirement contribution. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'RetirementCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment represented code: The code indicating whether an appointment is eligible to be represented, for collective bargaining purposes. (values are C=covered, S=supervisor-uncovered, or U=uncovered) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'RepresentedCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Pay rate code: The code indicating the nature of the rate of pay for the appointment. (values are A=annual, H=hourly, or B=by-agreement) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'RateCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Personnel program code: The code identifying the personnel program under which the appointment is held. (values are A=academic, 1=SSP-support staff and professionals, 2=MSP-management and senior professionals)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'PersonnelProgram';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Percent fulltime: The percentage of the budgeted position which the distribution represents. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'Percent';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Payment schedule code: The code indicating the pay schedule on which the appointment is paid. (values are BW=bi-weekly, SM=semi-monthly (not used at UCD), MO=monthly current, or MA=monthly arrears) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'PaySchedule';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Pay rate amount: The full time rate of pay (annual, hourly or by-agreement amount) associated with the appointment. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'PayRate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment months paid over flag: The code indicating the number of months during the year over which the individuals salary for the appointment is paid.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'PaidOver';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Leave accrual code: The code indicating the vacation and sick leave eligibility, accrual rates, and accrual maximums associated with the appointment. (translation in PAYROLL.DVTLVC table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'LeaveAccrualCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Is record in PPS?: A local flag, which indicates whether or not a person is in the current PPS dataset.  Used to determine if a person should be displayed as a current CA&ES employee. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'IsInPPS';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment salary grade: The salary grade associated with the appointment. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'Grade';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fixed/Variable time code: The code indicating whether the amount of time to be worked in an appointment is fixed or variable for each pay period. (values are F=fixed or V=variable) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'FixedVarCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment end date:  The date on which an appointment ended or is expected to end. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'EndDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee ID number: The unique employee identification number. (primary key)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'EmployeeID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment duration: The code indicating the expected duration of an appointment. (values are A=acting executive, E=no specific end date, I=indefinite, N=non-tenure, S=security of employment, T=tenure, V=for visa purposes only or BLANK=none of the above) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'Duration';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment department code: The code indicating the department or other administrative unit associated with the appointment. This dept number is not frequently used, instead the dept number on the distribution is more accurate. (translation in FISDataMart.Departments table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'Department';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment begin date: The date on which an individuals appointment is effective. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'BeginDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment number: The unique number used to identify an appointment. (primary key)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'ApptNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Add/Delete/Change flag: The UCD-created code indicating the most update activity applied to the employee. The code will stay set for 7 days after the ppsdw update at which time the ''D'' records will be deleted and the codes on the added and changed records will be blanked out. (values are A=add, C=change, D=delete) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'ADCCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Academic service months: The code indicating the service period on which an appointment is based. (values are 9=9 months, 10=10 months, 11=11 months or 12=12 months)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Appointments', @level2type = N'COLUMN', @level2name = N'AcademicBasis';

