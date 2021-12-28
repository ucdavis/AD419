CREATE TABLE [dbo].[Departments] (
    [HomeDeptNo]      CHAR (6)     NOT NULL,
    [Name]            VARCHAR (50) NULL,
    [Abbreviation]    VARCHAR (50) NULL,
    [SchoolCode]      VARCHAR (10) NOT NULL,
    [AdminClusterNo]  VARCHAR (6)  NULL,
    [MailCode]        VARCHAR (5)  NULL,
    [HomeOrgUnitCode] VARCHAR (4)  NULL,
    [IsAdminCluster]  BIT          NULL,
    [LastActionDate]  DATETIME     NULL,
    CONSTRAINT [PK_Departments] PRIMARY KEY CLUSTERED ([HomeDeptNo] ASC, [SchoolCode] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'The description of home department includes name, address, location (campus, field station, UCDMC) and school/division. The data originates from the Payroll Control Table (CTL) and is updated daily. The departments associated school/division is identified by the first two characters in the Mail Code/BOUC field or the first two characters in the Org Code. The school/division code is translated in the Schools table. A view of this table, the PAYROLL.CTVHME, has the name/address correctly formatted plus additional data fields for the division name, and location of the department. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'School code: Identifies the school/division that the department is associated with. It is the first two characters of the HomeOrgUnitCode.  The translation  can be found in the Schools table, which can be used to identify the school/division.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'SchoolCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Department name: The complete name of the department. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Mail code: The mail code assigned to the department. Originally used by UCD to identify which college/school the department belongs to. Still maintained however the newer field for this info is the HME_ORG_UNIT_CD.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'MailCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last action date: The effective date of the most recent action. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'LastActionDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'IsCluster: Flag indicating that the "Dept" is an Administrative cluster.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'IsAdminCluster';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Home organization unit code: Identifies the school/division that the department is associated with.   The first two characters are also listed as the SchoolCode field.  Use the SchoolCode or the first two characters of this field and the School table to identify the school/division. Field replaced the MailCode.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'HomeOrgUnitCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Home department number: The unique code indicating the department. (primary key)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'HomeDeptNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Cluster Code: HomeDeptNo of Cluster (if appropriate).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'AdminClusterNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Department abbreviation: The abbreviated name of the department.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Departments', @level2type = N'COLUMN', @level2name = N'Abbreviation';

