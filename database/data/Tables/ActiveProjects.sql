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
    [Notes] NVARCHAR(MAX) NULL,
    [ProjectDirector] NVARCHAR(200) NOT NULL,
    [PdEmailAddress] NVARCHAR(320) NOT NULL,
    CONSTRAINT [PK_ActiveProjects] PRIMARY KEY CLUSTERED ([AccessionNumber]),
    CONSTRAINT [UQ_ActiveProjects_ProjectNumber] UNIQUE ([ProjectNumber])
);
