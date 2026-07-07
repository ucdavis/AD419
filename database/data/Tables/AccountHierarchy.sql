CREATE TABLE [data].[AccountHierarchy]
(
    [Code]             NVARCHAR(50)   NOT NULL,
    [Description]      NVARCHAR(1000) NULL,
    [ParentLevel0Code] VARCHAR(20)    NULL,
    [ParentLevel0Name] NVARCHAR(1000) NULL,
    [ParentLevel1Code] VARCHAR(20)    NULL,
    [ParentLevel1Name] NVARCHAR(1000) NULL,
    [ParentLevel2Code] VARCHAR(20)    NULL,
    [ParentLevel2Name] NVARCHAR(1000) NULL,
    [ParentLevel3Code] VARCHAR(20)    NULL,
    [ParentLevel3Name] NVARCHAR(1000) NULL,
    [ParentLevel4Code] VARCHAR(20)    NULL,
    [ParentLevel4Name] NVARCHAR(1000) NULL,
    [ParentLevel5Code] VARCHAR(20)    NULL,
    [ParentLevel5Name] NVARCHAR(1000) NULL,
    [LoadedAt]         DATETIME2(3)   NOT NULL CONSTRAINT [DF_AccountHierarchy_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_AccountHierarchy] PRIMARY KEY CLUSTERED ([Code])
);
