CREATE TABLE [dbo].[Persons_PPS] (
    [EmployeeID]               CHAR (9)     NOT NULL,
    [FirstName]                VARCHAR (30) NULL,
    [MiddleName]               VARCHAR (30) NULL,
    [LastName]                 VARCHAR (30) NULL,
    [FullName]                 VARCHAR (50) NULL,
    [Suffix]                   VARCHAR (4)  NULL,
    [BirthDate]                DATETIME     NULL,
    [UCDMailID]                VARCHAR (32) NULL,
    [UCDLoginID]               VARCHAR (8)  NULL,
    [HomeDepartment]           VARCHAR (6)  NULL,
    [AlternateDepartment]      VARCHAR (6)  NULL,
    [AdministrativeDepartment] VARCHAR (6)  NULL,
    [SchoolDivision]           VARCHAR (2)  NULL,
    [PrimaryTitle]             VARCHAR (4)  NULL,
    [PrimaryApptNo]            VARCHAR (2)  NULL,
    [PrimaryDistNo]            VARCHAR (2)  NULL,
    [JobGroupID]               VARCHAR (3)  NULL,
    [HireDate]                 DATETIME     NULL,
    [OriginalHireDate]         DATETIME     NULL,
    [EmployeeStatus]           CHAR (1)     NULL,
    [StudentStatus]            CHAR (1)     NULL,
    [EducationLevel]           CHAR (1)     NULL,
    [BarganingUnit]            VARCHAR (2)  NULL,
    [LeaveServiceCredit]       SMALLINT     NULL,
    [Supervisor]               CHAR (1)     NULL,
    [LastChangeDate]           DATETIME     NULL,
    [IsInPPS]                  BIT          NULL,
    [PPS_ID]                   VARCHAR (10) NULL,
    [UCP_EMPLID]               VARCHAR (10) NULL,
    [HasUcpEmplId]             BIT          NULL,
    CONSTRAINT [PK_Persons] PRIMARY KEY CLUSTERED ([EmployeeID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [Persons_HireDate_IDX]
    ON [dbo].[Persons_PPS]([HireDate] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons_AlternateDepartment_IDX]
    ON [dbo].[Persons_PPS]([AlternateDepartment] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons_AdministrativeDepartment_IDX]
    ON [dbo].[Persons_PPS]([AdministrativeDepartment] ASC);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Is record in PPS?: A local flag, which indicates whether or not a person is in the current PPS dataset.  Used to determine if a person should be displayed as a current CA&ES employee. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'IsInPPS';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last change date: The date of the last change to the individuals records. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'LastChangeDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Supervisor indicator: The code indicating whether the title code associated with the employee is a supervisor title code. (values are Y=supervisor or N) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'Supervisor';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Leave accrual service credit:  The total number of qualifying months of employment service at the university, its DOE laboratories, and the State of California. (UCRS Retirement Service Credit is calculated at UCOP. This is for determining leave accrual rates - totals are updated during Monthly Maintenance.) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'LeaveServiceCredit';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Collective bargainning unit: The code indicating the primary collective bargaining unit of an individual derived from the predominant appointment. (translation in PAYROLL.DVTBUT table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'BarganingUnit';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Education level: The code indicating the highest level of education attained by the employee. (values are N=no credentials, H=high school diploma or equivalent, T=trade or craft certificate, A=associate degree, B=bacholor''s degree, M=master''s degree, P=professional degree, D=doctorate and BLANK=no information) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'EducationLevel';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Student status code: The code indicating whether the employee is a UC student. (values are 1=not registered, 2=not registered - graduate degree candidate, 3=undergraduate student, 4=graduate student, 5=not registered - graduate degree candidate at another UC campus, 6=undergraduate student at another UC campus, 7=graduate student at another UC campus) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'StudentStatus';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employment status: The code indicating the individual''s university employment status. (values are A=active, I=inactive, N=leave without pay, P=leave with pay, S=separated) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'EmployeeStatus';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Original hire date: The date on which the first employment affiliation commenced. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'OriginalHireDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Most current hired date: The date on which the most recent employment period commenced. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'HireDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Job group ID code: The code indicating the affirmative action job group associated with the primary title code. (translation in TitleGroups table)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'JobGroupID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary distribution number: The distribution number associated with the predominate appointment for the employee. (derived at UCD during update process by comparing percentage of time and funding) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'PrimaryDistNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary appointment number: The appointment number associated with the predominate appointment for the employee. (derived at UCD during update process by comparing percentage of time and job title) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'PrimaryApptNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary title code: The title code associated with the predominate appointment for the employee, based on a specified set of criteria. (derived at UCD during the update process) (translation in Titles table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'PrimaryTitle';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'School/Division Code: The UCD-created code that indicates the school/division to which the work home department belongs. If the work or alternate home department was blank, the primary home department was used to calculate the school/division. (translation in Schools table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'SchoolDivision';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'UCD administrative code: Number identifying a unique administrative department code associated to the employee ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'AdministrativeDepartment';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Alternate department code: The code indicating the department other than the primary where an employee works or would like their mail sent. May be blank. (translation in Departments table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'AlternateDepartment';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Administrative home department code: The code indicating the administrative or primary department responsible for coordinating the employees employment and/or pay disposition. This field should not be blank. (translation in CTLHME table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'HomeDepartment';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'UCD login identification: The unique identification to access a UC Davis computing system. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'UCDLoginID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'UCD e-mail address: The campus electronic mail address of the employee from the Mothra database. BLANK means no email address or employee indicated not to release this information. Append "@ucdavis.edu" to the UCD_MAILID address when using to send Email. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'UCDMailID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date of birth: The date on which the employee was born. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'BirthDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee name suffix: The suffix appended to an employees name. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'Suffix';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee full name: The name of the employee. Format is "last,first m" ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'FullName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee last name: The last name of the employee. NOTE: Field size change from former field UCD_LAST_NAME. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'LastName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee middle name: The middle name or initial of the employee. NOTE: Field size change from former field UCD_MIDDLE_NAME. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'MiddleName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee first name: The first name of the employee. NOTE: Field size different from former field UCD_FIRST_NAME.. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'FirstName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee ID number: The unique employee identification number. (Primary key)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS', @level2type = N'COLUMN', @level2name = N'EmployeeID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'One record exists for each employee and contains personnel-type (Personnel Data Form - PDF form) information: employment status, service credit, ethnicity, sex, bargaining unit representation and student/units information. Each employee record contains a primary/administrative home department and a secondary/work location home department which may or may not be the same department. The record will remain for employees separated within the calendar year (for W2-producing purposes). The data originates from the Employee Data Base (EDB). Additional indicator flags have been added to each record identifying employee type, confidentiality, work location, supervisory status, primary appointment number and primary distribution number. These flags and numbers are derived from a variety of EDB data fields. While the business rule would consider that an employee must be employed by one or more departments, there is no validation on the department code so some employees have department codes that are invalid or have yet to be added to the DEPARTMENT entity/table. The UCD_Mailid field included in this record is extracted from the UCDavis Mothra data base. It identifies the "Email alias@ucdavis.edu" that this employee can be reached at. This field may be blank as some employees either don''''t have an Email address or have identified in the Mothra system that their Email address should not be made public. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Persons_PPS';

