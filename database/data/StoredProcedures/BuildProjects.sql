CREATE PROCEDURE [data].[BuildProjects]
AS
BEGIN
    SET NOCOUNT ON;
    -- Any failure (including client-abort timeouts, which TRY/CATCH cannot see)
    -- must roll back the whole rebuild so Projects is never left empty.
    SET XACT_ABORT ON;

    -- Materializes the cycle's consolidated project list from ActiveProjects,
    -- AllProjects and PGMProjects: one row per NIFA project x AE project pair,
    -- or a single row with null PGM fields when a non-204 project has no PGM
    -- master data match.
    -- Runs as an import stage after step 1 settles the project list; downstream
    -- consumers (expense views, associations) read this table instead of
    -- re-deriving the joins. SFN comes from the NIFA project number suffix;
    -- NIFA/PGM SFN agreement is checked during Project Identification, so a
    -- single SFN is stored.

    IF NOT EXISTS (SELECT 1 FROM [data].[ActiveProjects])
        THROW 50000, 'ActiveProjects is empty; complete Project Identification before building the project list.', 1;

    -- Every included active project must appear in AllProjects; an unmatched
    -- project means Project Identification is not finished.
    IF EXISTS
    (
        SELECT 1
        FROM [data].[ActiveProjects] a
        LEFT JOIN [data].[AllProjects] ap
            ON NULLIF(LTRIM(RTRIM(ap.[ProjectNumber])), '') = NULLIF(LTRIM(RTRIM(a.[ProjectNumber])), '')
           AND NULLIF(LTRIM(RTRIM(ap.[AccessionNumber])), '') = NULLIF(LTRIM(RTRIM(a.[AccessionNumber])), '')
        WHERE ISNULL(a.[ExcludeFromUi], 0) = 0
          AND ap.[ProjectNumber] IS NULL
    )
        THROW 50000, 'Active projects exist without an AllProjects match; resolve them in Project Identification first.', 1;

    -- Only 204 (-CG) projects must map to a PGM master data record; other SFNs
    -- may build without one.
    IF EXISTS
    (
        SELECT 1
        FROM [data].[ActiveProjects] a
        JOIN [data].[AllProjects] ap
            ON NULLIF(LTRIM(RTRIM(ap.[ProjectNumber])), '') = NULLIF(LTRIM(RTRIM(a.[ProjectNumber])), '')
           AND NULLIF(LTRIM(RTRIM(ap.[AccessionNumber])), '') = NULLIF(LTRIM(RTRIM(a.[AccessionNumber])), '')
        LEFT JOIN [data].[v_PgmProjectSfnBuckets] pc
            ON ap.[AwardNumber] IS NOT NULL
           AND pc.[AwardKey] = REPLACE(ap.[AwardNumber], '-', '')
        WHERE ISNULL(a.[ExcludeFromUi], 0) = 0
          AND a.[ProjectNumber] LIKE '%-CG'
          AND pc.[ProjectNumber] IS NULL
    )
        THROW 50000, '204 projects exist without a PGM master data match; resolve them in Project Identification first.', 1;

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
        a.[AccessionNumber],
        a.[ProjectNumber],
        ap.[AwardNumber],
        ap.[Title],
        ap.[ProjectStartDate],
        ap.[ProjectEndDate],
        a.[ProjectDirector],
        a.[UcpEmployeeId],
        a.[Is204],
        CASE
            WHEN a.[ProjectNumber] LIKE '%-H'  THEN '201'
            WHEN a.[ProjectNumber] LIKE '%-RR' THEN '202'
            WHEN a.[ProjectNumber] LIKE '%-CG' THEN '204'
            WHEN a.[ProjectNumber] LIKE '%-AH' THEN '205'
            ELSE 'UNKNOWN'  -- unrecognized suffix: fail closed, never silently classified
        END,
        pc.[ProjectNumber],
        pc.[SponsorAwardNumber],
        pgm.[PrincipalInvestigatorNames]
    FROM [data].[ActiveProjects] a
    JOIN [data].[AllProjects] ap
        ON NULLIF(LTRIM(RTRIM(ap.[ProjectNumber])), '') = NULLIF(LTRIM(RTRIM(a.[ProjectNumber])), '')
       AND NULLIF(LTRIM(RTRIM(ap.[AccessionNumber])), '') = NULLIF(LTRIM(RTRIM(a.[AccessionNumber])), '')
    LEFT JOIN [data].[v_PgmProjectSfnBuckets] pc
        ON ap.[AwardNumber] IS NOT NULL
       AND pc.[AwardKey] = REPLACE(ap.[AwardNumber], '-', '')
    LEFT JOIN [data].[PGMProjects] pgm
        ON pgm.[ProjectId] = pc.[ProjectId]
    WHERE ISNULL(a.[ExcludeFromUi], 0) = 0;

    COMMIT;

    -- Row count for the import run stage.
    SELECT COUNT(*) AS ProjectRowsBuilt FROM [data].[Projects];
END
