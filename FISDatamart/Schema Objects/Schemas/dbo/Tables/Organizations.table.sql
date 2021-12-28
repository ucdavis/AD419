CREATE TABLE [dbo].[Organizations] (
    [Year]            INT           NOT NULL,
    [Period]          CHAR (2)      NOT NULL,
    [Org]             CHAR (4)      NOT NULL,
    [Chart]           VARCHAR (2)   NOT NULL,
    [Level]           TINYINT       NOT NULL,
    [Name]            VARCHAR (40)  NULL,
    [Type]            CHAR (4)      NOT NULL,
    [BeginDate]       DATETIME2 (0) NULL,
    [EndDate]         DATETIME      NULL,
    [HomeDeptNum]     CHAR (6)      NULL,
    [HomeDeptName]    VARCHAR (40)  NULL,
    [UpdateDate]      DATETIME      NULL,
    [Chart1]          VARCHAR (2)   NOT NULL,
    [Org1]            CHAR (4)      NOT NULL,
    [Name1]           VARCHAR (40)  NOT NULL,
    [Chart2]          VARCHAR (2)   NULL,
    [Org2]            CHAR (4)      NULL,
    [Name2]           VARCHAR (40)  NULL,
    [Chart3]          VARCHAR (2)   NULL,
    [Org3]            CHAR (4)      NULL,
    [Name3]           VARCHAR (40)  NULL,
    [Chart4]          VARCHAR (2)   NULL,
    [Org4]            CHAR (4)      NULL,
    [Name4]           VARCHAR (40)  NULL,
    [Chart5]          VARCHAR (2)   NULL,
    [Org5]            CHAR (4)      NULL,
    [Name5]           VARCHAR (40)  NULL,
    [Chart6]          VARCHAR (2)   NULL,
    [Org6]            CHAR (4)      NULL,
    [Name6]           VARCHAR (40)  NULL,
    [Chart7]          VARCHAR (2)   NULL,
    [Org7]            CHAR (4)      NULL,
    [Name7]           VARCHAR (40)  NULL,
    [Chart8]          VARCHAR (2)   NULL,
    [Org8]            CHAR (4)      NULL,
    [Name8]           VARCHAR (40)  NULL,
    [Chart9]          VARCHAR (2)   NULL,
    [Org9]            CHAR (4)      NULL,
    [Name9]           VARCHAR (40)  NULL,
    [Chart10]         VARCHAR (2)   NULL,
    [Org10]           CHAR (4)      NULL,
    [Name10]          VARCHAR (40)  NULL,
    [Chart11]         VARCHAR (2)   NULL,
    [Org11]           CHAR (4)      NULL,
    [Name11]          VARCHAR (40)  NULL,
    [Chart12]         VARCHAR (2)   NULL,
    [Org12]           CHAR (4)      NULL,
    [Name12]          VARCHAR (40)  NULL,
    [ActiveIndicator] CHAR (1)      NULL,
    [OrganizationPK]  VARCHAR (14)  NULL,
    [LastUpdateDate]  SMALLDATETIME NULL,
    CONSTRAINT [PK_Organizations] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Org] ASC, [Chart] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial Organization Reporting Hierarchy: Documents the hierarchical structure of organizations within the financial system.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Hierarchy Effective Record Fiscal Year: The fiscal year in which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Hierarchy Effective Record Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Hierarchy Level: Shows the level of the Organization within the user defined "Reports To" hierarchy. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Level';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Type Code: Code indicating if this organization is a dean or vice chancellor, associate dean or vice chancellor or a department, unit or division.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Type';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Begin Date: The assigned begin date for this organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'BeginDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization End Date: The assigned end date for this organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'EndDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Home Department Number: Currently used to identify campus departments for Payroll and report distribution.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'HomeDeptNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Home Department Primary Name: Descriptive name for the primary Home Department', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'HomeDeptName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last Organization Record Update Date: The last date that this organization record was changed', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'UpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number For Level 1 Organization: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier For Level 1 Organization: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name For Level 1 Organization: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'
Chart Of Accounts Number For Level 2 Organization: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart2';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier For Level 2 Organization: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org2';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name For Level 2 Organization: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name2';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'
Chart Of Accounts Number For Level 3 Organization: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart3';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'
Organization Identifier For Level 3 Organization: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org3';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name For Level 3 Organization: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name3';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'
Chart Of Accounts Number For Level 4 Organization: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart4';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'
Organization Identifier For Level 4 Organization: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org4';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name For Level 4 Organization: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name4';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number For Level 5 Organization: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart5';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier For Level 5 Organization: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org5';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name For Level 5 Organization: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name5';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number For Level 6 Organization: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Chart6';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier For Level 6 Organization: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Org6';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Name For Level 6 Organization: Descriptive name given to an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'Name6';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key: Unique identifier used for performing FK joins on other tables, comprised of Year, Period, Org and Chart.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Organizations', @level2type = N'COLUMN', @level2name = N'OrganizationPK';

