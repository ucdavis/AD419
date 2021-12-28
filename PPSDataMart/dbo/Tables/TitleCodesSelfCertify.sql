CREATE TABLE [dbo].[TitleCodesSelfCertify] (
    [Id]                INT            IDENTITY (1, 1) NOT NULL,
    [TitleCode]         NVARCHAR (255) NULL,
    [Name]              NVARCHAR (255) NULL,
    [ClassTitleOutline] NVARCHAR (255) NULL,
    CONSTRAINT [PK_TitleCodesSelfCertify] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employees in these title codes must self-certify their effort reports.  Rev 11/2/2016.  Employee within these title codes are checked against the account PI''s list in order to determine if a match can be found.  Effor for employees with with PI name matches are considered 241 for the purposes of AD-419 effort reporting.  However, typically the effort for employees with these title codes ia reported as 242 when no match is found.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'TitleCodesSelfCertify';

