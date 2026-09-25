CREATE TABLE [data].[AutoAssociationExcludedProjects]
(
    -- NIFA projects whose dry-run association total is under $100. They get
    -- no auto-associations this cycle (final reports re-add them). Rebuilt
    -- whole by BuildAutoAssociations.
    [AccessionNumber]   NVARCHAR(7)    NOT NULL,
    [NifaProjectNumber] NVARCHAR(20)   NOT NULL,
    [Total]             DECIMAL(19, 4) NOT NULL,
    CONSTRAINT [PK_AutoAssociationExcludedProjects] PRIMARY KEY CLUSTERED ([AccessionNumber])
);
