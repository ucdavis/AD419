CREATE TABLE [dbo].[CesListImport] (
    [PI]                  VARCHAR (200)   NULL,
    [DeptLevelOrg]        VARCHAR (4)     NULL,
    [EmployeeId]          VARCHAR (10)    NULL,
    [ProjectAccessionNum] VARCHAR (11)    NULL,
    [ProjectNumber]       VARCHAR (20)    NULL,
    [PercentCeEffort]     DECIMAL (10, 2) NULL,
    [FullAnnualPayRate]   DECIMAL (18, 2) NULL,
    [TitleCode]           VARCHAR (4)     NULL,
    [FTE]                 DECIMAL (10, 2) NULL,
    [Chart]               VARCHAR (2)     NULL,
    [Account]             VARCHAR (7)     NULL,
    [SubAccount]          VARCHAR (5)     NULL,
    [EstimatedCeExpenses] DECIMAL (18, 2) NULL,
    [Id]                  INT             IDENTITY (1, 1) NOT NULL,
    CONSTRAINT [PK_CesListImport] PRIMARY KEY CLUSTERED ([Id] ASC)
);

