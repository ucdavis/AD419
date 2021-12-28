CREATE TABLE [dbo].[TitleGroups] (
    [JobGroupID]     VARCHAR (3)  NOT NULL,
    [Description]    VARCHAR (50) NULL,
    [Abbreviation]   VARCHAR (20) NULL,
    [LastActionDate] DATETIME     NULL,
    CONSTRAINT [PK_TitleGroups] PRIMARY KEY CLUSTERED ([JobGroupID] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'The campus-defined translation list for the job group code such as Academic Administrator, Technicians, and Administrative Specialists. This code and related description is tied to the job title through the Titles table. The data originates from the Payroll Control Table (CTL).
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TitleGroups';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last action date: The effective date of the most recent, highest priority, personnel action. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TitleGroups', @level2type = N'COLUMN', @level2name = N'LastActionDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Job/Title group ID code: The unique code indicating the type of job/title group id. (Primary key)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TitleGroups', @level2type = N'COLUMN', @level2name = N'JobGroupID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Job/Title group ID code description: The complete description of the job/title group id code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TitleGroups', @level2type = N'COLUMN', @level2name = N'Description';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Job/Title group ID code abbreviated description: The short description of the job/title group id code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TitleGroups', @level2type = N'COLUMN', @level2name = N'Abbreviation';

