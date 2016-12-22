CREATE TABLE [dbo].[InterdepartmentalProjectsImport] (
    [Id]              INT         IDENTITY (1, 1) NOT NULL,
    [AccessionNumber] VARCHAR (7) NOT NULL,
    [OrgR]            VARCHAR (4) NOT NULL,
    [Year]            INT         NOT NULL,
    CONSTRAINT [PK_Interdepartmental] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UC_Codes] UNIQUE NONCLUSTERED ([AccessionNumber] ASC, [OrgR] ASC, [Year] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Interdepartmental Project Mapping: Distinguishes which departments are associated with a single interdepartmental project.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'InterdepartmentalProjectsImport';

