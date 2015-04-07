CREATE TABLE [dbo].[2012ReportingCheckList] (
    [Id]              INT            IDENTITY (1, 1) NOT NULL,
    [Investigator]    NVARCHAR (255) NULL,
    [Fund]            NVARCHAR (255) NULL,
    [Project Number]  NVARCHAR (255) NULL,
    [Accession]       NVARCHAR (255) NULL,
    [Start Date]      DATETIME       NULL,
    [Term Date]       DATETIME       NULL,
    [Status]          NVARCHAR (255) NULL,
    [Dept]            NVARCHAR (255) NULL,
    [Dept Code]       NVARCHAR (255) NULL,
    [Dept Name]       NVARCHAR (255) NULL,
    [1st Coop Dept#]  NVARCHAR (255) NULL,
    [2nd Coop# Dept#] NVARCHAR (255) NULL
);

