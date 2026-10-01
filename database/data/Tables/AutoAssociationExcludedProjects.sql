CREATE TABLE [data].[AutoAssociationExcludedProjects]
(
    -- 204 NIFA projects whose direct expenses (included AE and UCPath rows on
    -- their AE projects) total under $100, including $0. They get no
    -- auto-associations this cycle (final reports re-add them). Non-204
    -- projects never appear here. Rebuilt whole by BuildAutoAssociations.
    [AccessionNumber]   NVARCHAR(7)    NOT NULL,
    [NifaProjectNumber] NVARCHAR(20)   NOT NULL,
    [Total]             DECIMAL(19, 4) NOT NULL,
    CONSTRAINT [PK_AutoAssociationExcludedProjects] PRIMARY KEY CLUSTERED ([AccessionNumber])
);
