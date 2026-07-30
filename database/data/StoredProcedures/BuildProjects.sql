CREATE PROCEDURE [data].[BuildProjects]
AS
BEGIN
    SET NOCOUNT ON;
    -- Any failure (including client-abort timeouts, which TRY/CATCH cannot see)
    -- must roll back the whole rebuild so Projects is never left empty.
    SET XACT_ABORT ON;

    -- Materializes the cycle's consolidated project list from v_NifaProjects
    -- and the PGM master data: one row per NIFA project x AE project pair, or
    -- a single row with null PGM fields when a non-204 project has no PGM
    -- master data match. Runs as an import stage after step 1 settles the
    -- project list; downstream consumers (expense views, associations) read
    -- this table instead of re-deriving the joins.

    IF NOT EXISTS (SELECT 1 FROM [data].[ActiveProjects])
        THROW 50000, 'ActiveProjects is empty; complete Project Identification before building the project list.', 1;

    -- Fail closed on the same definition the Project Identification UI shows:
    -- any non-Clean project means identification is not finished.
    IF EXISTS (SELECT 1 FROM [data].[v_ProjectList] WHERE [Status] <> 'Clean')
        THROW 50000, 'Unresolved project issues exist; resolve them in Project Identification first.', 1;

    BEGIN TRAN;

    DELETE FROM [data].[Projects];

    INSERT INTO [data].[Projects]
    (
        [AccessionNumber],
        [NifaProjectNumber],
        [NifaAwardNumber],
        [Title],
        [ProjectStartDate],
        [ProjectEndDate],
        [ProjectDirector],
        [UcpEmployeeId],
        [Is204],
        [Sfn],
        [AEProjectNumber],
        [SponsorAwardNumber],
        [PrincipalInvestigatorNames]
    )
    SELECT
        nv.[AccessionNumber],
        nv.[ProjectNumber],
        nv.[AwardNumber],
        nv.[Title],
        nv.[ProjectStartDate],
        nv.[ProjectEndDate],
        nv.[ProjectDirector],
        nv.[UcpEmployeeId],
        nv.[Is204],
        nv.[NifaSfn],
        pc.[ProjectNumber],
        pc.[SponsorAwardNumber],
        pgm.[PrincipalInvestigatorNames]
    FROM [data].[v_NifaProjects] nv
    LEFT JOIN [data].[v_PgmProjectSfnBuckets] pc
        ON pc.[AwardKey] = nv.[AwardKey]
    LEFT JOIN [data].[PGMProjects] pgm
        ON pgm.[ProjectId] = pc.[ProjectId]
    WHERE nv.[ExcludeFromUi] = 0;

    COMMIT;

    -- Row count for the import run stage.
    SELECT COUNT(*) AS ProjectRowsBuilt FROM [data].[Projects];
END
