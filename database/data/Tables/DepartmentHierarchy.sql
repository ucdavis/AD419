CREATE TABLE [data].[DepartmentHierarchy]
(
    [Code]             VARCHAR(20)    NOT NULL,
    [Description]      NVARCHAR(1000) NULL,
    [ParentLevelACode] VARCHAR(20)    NULL,
    [ParentLevelAName] NVARCHAR(1000) NULL,
    [ParentLevelBCode] VARCHAR(20)    NULL,
    [ParentLevelBName] NVARCHAR(1000) NULL,
    [ParentLevelCCode] VARCHAR(20)    NULL,
    [ParentLevelCName] NVARCHAR(1000) NULL,
    [ParentLevelDCode] VARCHAR(20)    NULL,
    [ParentLevelDName] NVARCHAR(1000) NULL,
    [ParentLevelECode] VARCHAR(20)    NULL,
    [ParentLevelEName] NVARCHAR(1000) NULL,
    [ParentLevelFCode] VARCHAR(20)    NULL,
    [ParentLevelFName] NVARCHAR(1000) NULL,
    [ParentLevelGCode] VARCHAR(20)    NULL,
    [ParentLevelGName] NVARCHAR(1000) NULL,
    [LoadedAt]         DATETIME2(3)   NOT NULL CONSTRAINT [DF_DepartmentHierarchy_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_DepartmentHierarchy] PRIMARY KEY CLUSTERED ([Code])
);
