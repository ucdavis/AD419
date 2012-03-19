CREATE TABLE [dbo].[Projects] (
    [Year]           INT           NOT NULL,
    [Period]         CHAR (2)      NOT NULL,
    [Number]         VARCHAR (10)  NOT NULL,
    [Name]           VARCHAR (40)  NULL,
    [ManagerID]      CHAR (8)      NULL,
    [Chart]          VARCHAR (2)   NOT NULL,
    [OrgID]          CHAR (4)      NULL,
    [ActiveInd]      CHAR (1)      NULL,
    [Description]    TEXT          NULL,
    [LastUpdateDate] SMALLDATETIME NULL,
    [ProjectsPK]     VARCHAR (21)  NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial Project Reference Data: Contains the attributes of a UCD project.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Record Effective Fiscal Year: The fiscal year in which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Record Effective Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Number: Code used to track and accumulate transactions across multiple charts, accounts and fund groups.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'Number';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Name: The descriptive name of the project', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Manager Id: The user id of the person who is responsible in some way for the financial activity on a project.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'ManagerID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'OrgID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Active Code: A "Y" or "N" to show whether the project is currently active (Y) or inactive (N).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'ActiveInd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Description: A long textual description of the purpose of the project.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'Description';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last TP Update Date: Last update date of the project in TP', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key: Unique identifier used for performing FK joins with other tables comprised of Year, Period, Number.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Projects', @level2type = N'COLUMN', @level2name = N'ProjectsPK';

