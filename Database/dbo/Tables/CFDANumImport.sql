CREATE TABLE [dbo].[CFDANumImport] (
    [CFDANum]      VARCHAR (10)  NULL,
    [ProgramTitle] VARCHAR (300) NULL,
    [Id]           INT           IDENTITY (1, 1) NOT NULL,
    CONSTRAINT [PK_CFDANum] PRIMARY KEY CLUSTERED ([Id] ASC)
);

