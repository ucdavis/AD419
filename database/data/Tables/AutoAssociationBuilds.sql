CREATE TABLE [data].[AutoAssociationBuilds]
(
    -- One row per completed build (the procedure clears the table first), so
    -- the Auto-Associations stage can show when and for which cycle the
    -- staging data was produced.
    [BuildId]             INT          NOT NULL IDENTITY(1, 1),
    [CycleStart]          DATE         NOT NULL,
    [CycleEnd]            DATE         NOT NULL,
    [BuiltAt]             DATETIME2(3) NOT NULL CONSTRAINT [DF_AutoAssociationBuilds_BuiltAt] DEFAULT (SYSUTCDATETIME()),
    [SummaryRows]         INT          NOT NULL,
    [AssociationRows]     INT          NOT NULL,
    [ExcludedProjects]    INT          NOT NULL,
    [Misclassified204Rows] INT         NOT NULL,
    CONSTRAINT [PK_AutoAssociationBuilds] PRIMARY KEY CLUSTERED ([BuildId])
);
