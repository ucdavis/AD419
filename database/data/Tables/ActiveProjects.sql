CREATE TABLE [data].[ActiveProjects]
(
    [ProjectNumber] NVARCHAR(20) NOT NULL,
    [AccessionNumber] NVARCHAR(7) NOT NULL,
    [UcpEmployeeId] NVARCHAR(8) NOT NULL,
    [UcPathName] NVARCHAR(200) NOT NULL,
    [Is204] BIT NOT NULL,
    [ExcludeFromUi] BIT NULL,
    [AllProjectIdOverride] INT NULL,
    [PgmAwardKeyOverride] NVARCHAR(100) NULL,
    [SfnOverride] NVARCHAR(10) NULL,
    [ProjectNumberNormalized] AS CONVERT(NVARCHAR(20), NULLIF(LTRIM(RTRIM([ProjectNumber])), N'')) PERSISTED,
    [AccessionNumberNormalized] AS CONVERT(NVARCHAR(7), NULLIF(LTRIM(RTRIM([AccessionNumber])), N'')) PERSISTED,
    [PgmAwardKeyOverrideNormalized] AS CONVERT(NVARCHAR(100), NULLIF(REPLACE(LTRIM(RTRIM([PgmAwardKeyOverride])), N'-', N''), N'')) PERSISTED,
    [Notes] NVARCHAR(MAX) NULL,
    [ProjectDirector] NVARCHAR(200) NOT NULL,
    [PdEmailAddress] NVARCHAR(320) NOT NULL,
    CONSTRAINT [PK_ActiveProjects] PRIMARY KEY CLUSTERED ([AccessionNumber]),
    CONSTRAINT [UQ_ActiveProjects_ProjectNumber] UNIQUE ([ProjectNumber]),
    CONSTRAINT [CK_ActiveProjects_SfnOverride_Domain] CHECK (
        [SfnOverride] IS NULL OR LTRIM(RTRIM([SfnOverride])) IN (N'201', N'202', N'203', N'204', N'205', N'209', N'219', N'220', N'221', N'222', N'223')
    ),
    CONSTRAINT [CK_ActiveProjects_PgmAwardKeyOverride_NotBlank] CHECK (
        [PgmAwardKeyOverride] IS NULL OR [PgmAwardKeyOverrideNormalized] IS NOT NULL
    )
);
