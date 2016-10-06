CREATE TABLE [dbo].[InterdepartmentalProjectsImport] (
    [Id]              INT         IDENTITY (1, 1) NOT NULL,
    [AccessionNumber] VARCHAR (7) NOT NULL,
    [OrgR]            VARCHAR (4) NOT NULL,
    [Year]            INT         NOT NULL,
    CONSTRAINT [PK_Interdepartmental] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UC_Codes] UNIQUE NONCLUSTERED ([AccessionNumber] ASC, [OrgR] ASC, [Year] ASC)
);

