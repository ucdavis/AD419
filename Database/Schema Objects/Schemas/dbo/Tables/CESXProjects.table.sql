CREATE TABLE [dbo].[CESXProjects] (
    [EID]                  VARCHAR (9) NULL,
    [Accession]            CHAR (7)    NULL,
    [OrgR]                 CHAR (4)    NULL,
    [PctEffort]            FLOAT       NULL,
    [CESSalaryExpenses]    FLOAT       NULL,
    [CESNonSalaryExpenses] NCHAR (10)  NULL,
    [PctFTE]               TINYINT     NULL,
    [idCESXProject]        INT         IDENTITY (1, 1) NOT NULL
);

