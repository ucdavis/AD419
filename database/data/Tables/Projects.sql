CREATE TABLE [data].[Projects]
(
    [Id]                          BIGINT        NOT NULL IDENTITY(1, 1),

    -- NIFA side (from ActiveProjects joined to AllProjects)
    [AccessionNumber]             NVARCHAR(7)   NOT NULL,
    [NifaProjectNumber]           NVARCHAR(20)  NOT NULL,
    [NifaAwardNumber]             NVARCHAR(16)  NULL,
    [Title]                       NVARCHAR(MAX) NULL,
    [ProjectStartDate]            DATE          NULL,
    [ProjectEndDate]              DATE          NULL,
    [ProjectDirector]             NVARCHAR(200) NULL,
    [UcpEmployeeId]               NVARCHAR(8)   NULL,
    [Is204]                       BIT           NOT NULL,
    [Sfn]                         NVARCHAR(7)   NOT NULL, -- from project number suffix: 201 | 202 | 204 | 205 | UNKNOWN

    -- AE side (from PGMProjects via award number match). Null when the project
    -- has no PGM master data match, which is the norm for non-204 projects
    -- (Hatch and animal health are state funded with no AE project). The
    -- Project Identification guard requires a match, and therefore a value,
    -- for every 204 row; only the 204 rows feed the import carve-out lists.
    [AEProjectNumber]             NVARCHAR(50)  NULL,
    [SponsorAwardNumber]          NVARCHAR(100) NULL,
    [PrincipalInvestigatorNames]  NVARCHAR(MAX) NULL,

    [LoadedAt]                    DATETIME2(3)  NULL CONSTRAINT [DF_Projects_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED ([Id])
);
