CREATE TABLE [dbo].[CESXProjects] (
    [EID]                  VARCHAR (9) NULL,
    [Accession]            CHAR (7)    NULL,
    [Chart]                VARCHAR (2) NULL,
    [OrgR]                 CHAR (4)    NULL,
    [Account]              VARCHAR (7) NULL,
    [SubAccount]           VARCHAR (5) NULL,
    [PctEffort]            FLOAT (53)  NULL,
    [CESSalaryExpenses]    FLOAT (53)  NULL,
    [CESNonSalaryExpenses] NCHAR (10)  NULL,
    [PctFTE]               TINYINT     NULL,
    [idCESXProject]        INT         IDENTITY (1, 1) NOT NULL,
    CONSTRAINT [PK_CESXProjects] PRIMARY KEY CLUSTERED ([idCESXProject] ASC)
);



