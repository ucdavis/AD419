CREATE TABLE [data].[ChartSegments]
(
    [SegmentName]      NVARCHAR(30)  NOT NULL,  -- Entity | Fund | FinancialDepartment | Account | Purpose | Program | Project | Activity
    [Code]             NVARCHAR(300) NOT NULL,
    [ValueId]          BIGINT        NULL,
    [Description]      NVARCHAR(500) NULL,
    [ValueDesc]        NVARCHAR(800) NULL,
    [HierarchyDepth]   INT           NULL,
    [SummaryFlag]      NVARCHAR(60)  NULL,
    [EnabledFlag]      NVARCHAR(4)   NULL,
    [StartDateActive]  DATE          NULL,
    [EndDateActive]    DATE          NULL,
    [ParentLevel0Code] NVARCHAR(200) NULL,
    [ParentLevel1Code] NVARCHAR(200) NULL,
    [ParentLevel2Code] NVARCHAR(200) NULL,
    [ParentLevel3Code] NVARCHAR(200) NULL,
    [ParentLevel4Code] NVARCHAR(200) NULL,
    [ParentLevel5Code] NVARCHAR(200) NULL,
    [LoadedAt]         DATETIME2(3)  NULL CONSTRAINT [DF_ChartSegments_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_ChartSegments] PRIMARY KEY CLUSTERED ([SegmentName], [Code])
);
