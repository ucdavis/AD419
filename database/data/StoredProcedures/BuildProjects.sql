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

    -- Fail closed on the shared readiness definition (also used by the import
    -- trigger endpoint, which normally rejects a not-ready run before it starts).
    DECLARE @blockingIssue NVARCHAR(200) = (SELECT [Issue] FROM [data].[v_ImportBlockingIssue]);
    IF @blockingIssue IS NOT NULL
        THROW 50000, @blockingIssue, 1;

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

    -- Counts for the import run stage: rows are NIFA x AE project pairs (204
    -- awards fan out to many AE projects), so both grains are reported.
    SELECT
        COUNT(*) AS AeProjects,
        COUNT(DISTINCT [AccessionNumber]) AS NifaProjects
    FROM [data].[Projects];
END
