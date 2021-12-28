CREATE TABLE [dbo].[Persons] (
    [EmployeeID]               CHAR (9)        NOT NULL,
    [FirstName]                VARCHAR (30)    NULL,
    [MiddleName]               VARCHAR (30)    NULL,
    [LastName]                 VARCHAR (30)    NULL,
    [FullName]                 VARCHAR (50)    NULL,
    [Suffix]                   VARCHAR (4)     NULL,
    [BirthDate]                DATETIME2 (7)   NULL,
    [UCDMailID]                VARCHAR (50)    NULL,
    [UCDLoginID]               VARCHAR (8)     NULL,
    [HomeDepartment]           VARCHAR (6)     NULL,
    [AlternateDepartment]      VARCHAR (6)     NULL,
    [AdministrativeDepartment] VARCHAR (6)     NULL,
    [SchoolDivision]           VARCHAR (6)     NULL,
    [PrimaryTitle]             VARCHAR (4)     NULL,
    [PrimaryApptNo]            VARCHAR (8)     NULL,
    [PrimaryDistNo]            VARCHAR (2)     NULL,
    [JobGroupID]               VARCHAR (3)     NULL,
    [HireDate]                 DATETIME2 (7)   NULL,
    [OriginalHireDate]         DATETIME2 (7)   NULL,
    [EmployeeStatus]           CHAR (1)        NULL,
    [StudentStatus]            CHAR (1)        NULL,
    [EducationLevel]           CHAR (2)        NULL,
    [BarganingUnit]            VARCHAR (2)     NULL,
    [LeaveServiceCredit]       NUMERIC (14, 2) NULL,
    [Supervisor]               CHAR (1)        NULL,
    [LastChangeDate]           DATETIME2 (7)   NULL,
    [IsInPPS]                  BIT             NULL,
    [PPS_ID]                   VARCHAR (10)    NULL,
    [UCP_EMPLID]               VARCHAR (10)    NULL,
    [HasUcpEmplId]             BIT             NULL,
    CONSTRAINT [PK_Persons_1] PRIMARY KEY CLUSTERED ([EmployeeID] ASC)
);




GO
CREATE NONCLUSTERED INDEX [Persons2_UCDLoginID_NCLINDX]
    ON [dbo].[Persons]([UCDLoginID] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_SchDivision_NCLINDX]
    ON [dbo].[Persons]([SchoolDivision] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_LastName_NCLINDX]
    ON [dbo].[Persons]([LastName] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_LastName_FirstName_MI_NCLINDX]
    ON [dbo].[Persons]([LastName] ASC, [FullName] ASC, [MiddleName] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_HomeDept_NCLINDX]
    ON [dbo].[Persons]([HomeDepartment] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_HireDate_NCLINDX]
    ON [dbo].[Persons]([HireDate] DESC);


GO
CREATE NONCLUSTERED INDEX [Persons2_FullName_NCLINDX]
    ON [dbo].[Persons]([FullName] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_FirstName_NCLINDX]
    ON [dbo].[Persons]([FirstName] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_EmpStatus_NCLINDX]
    ON [dbo].[Persons]([EmployeeStatus] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_EmployeeID_NCLINDX]
    ON [dbo].[Persons]([EmployeeID] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_AlternateDepartment_NCLINDX]
    ON [dbo].[Persons]([AlternateDepartment] ASC);


GO
CREATE NONCLUSTERED INDEX [Persons2_AdministrativeDepartment_NCLINDX]
    ON [dbo].[Persons]([AdministrativeDepartment] ASC);

