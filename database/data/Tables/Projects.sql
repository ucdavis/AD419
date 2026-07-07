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
    [NifaSfn]                     NVARCHAR(7)   NULL,   -- from project number suffix: 201 | 202 | 204 | 205 | UNKNOWN

    -- AE side (from PGMProjects via award number match; NULL when no PGM match)
    [AEProjectNumber]             NVARCHAR(50)  NULL,
    [SponsorAwardNumber]          NVARCHAR(100) NULL,
    [PgmSfnBucket]                NVARCHAR(10)  NULL,   -- CFDA-derived: HATCH | 203 | 204 | 205 | NON-NIFA | NULL
    [PrincipalInvestigatorNames]  NVARCHAR(MAX) NULL,

    [LoadedAt]                    DATETIME2(3)  NULL CONSTRAINT [DF_Projects_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED ([Id])
);
