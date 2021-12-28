CREATE TABLE [dbo].[CFDANumImport] (
    [Id]           INT            IDENTITY (1, 1) NOT NULL,
    [CFDANum]      VARCHAR (10)   NULL,
    [ProgramTitle] VARCHAR (300)  NULL,
    [AgencyOffice] VARCHAR (2048) NULL,
    [Code]         VARCHAR (10)   NULL,
    CONSTRAINT [PK_CFDANum] PRIMARY KEY CLUSTERED ([Id] ASC)
);



