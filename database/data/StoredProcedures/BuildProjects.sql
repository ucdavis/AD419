CREATE PROCEDURE [data].[BuildProjects]
AS
BEGIN
    SET NOCOUNT ON;

    -- Materializes the cycle's consolidated project list from ActiveProjects,
    -- AllProjects and PGMProjects: one row per NIFA project x AE project pair
    -- (a NIFA project with no PGM match is one row with NULL AE fields).
    -- Runs as an import stage after step 1 settles the project list; downstream
    -- consumers (classify sproc 204 carve-out, expense views, associations)
    -- read this table instead of re-deriving the joins.

    IF NOT EXISTS (SELECT 1 FROM [data].[ActiveProjects])
        THROW 50000, 'ActiveProjects is empty; complete Project Identification before building the project list.', 1;

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
        [NifaSfn],
        [AEProjectNumber],
        [SponsorAwardNumber],
        [PgmSfnBucket],
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
        pc.[PgmSfnBucket],
        pgm.[PrincipalInvestigatorNames]
    FROM [data].[ActiveProjects] a
    LEFT JOIN [data].[AllProjects] ap
        ON ap.[ProjectNumber] = a.[ProjectNumber]
    LEFT JOIN [data].[v_PgmProjectSfnBuckets] pc
        ON ap.[AwardNumber] IS NOT NULL
       AND pc.[AwardKey] = REPLACE(ap.[AwardNumber], '-', '')
    LEFT JOIN [data].[PGMProjects] pgm
        ON pgm.[ProjectId] = pc.[ProjectId]
    WHERE ISNULL(a.[ExcludeFromUi], 0) = 0;

    -- Row count for the import run stage.
    SELECT COUNT(*) AS ProjectRowsBuilt FROM [data].[Projects];
END
