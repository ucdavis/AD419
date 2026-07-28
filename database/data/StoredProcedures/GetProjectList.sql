CREATE PROCEDURE [data].[GetProjectList]
    @cycleStart DATE,
    @cycleEnd   DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @cycleStart IS NULL OR @cycleEnd IS NULL
        THROW 50000, '@cycleStart and @cycleEnd are required.', 1;

    IF @cycleStart > @cycleEnd
        THROW 50000, '@cycleStart must not be after @cycleEnd.', 1;

    WITH AlnCatalog AS
    (
        SELECT
            ProgramNumber,
            MAX(CASE
                WHEN FederalAgency030 LIKE 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE%' THEN 1
                ELSE 0
            END) AS IsNifa
        FROM [data].[AssistanceListingNumbers]
        WHERE ProgramNumber IS NOT NULL
        GROUP BY ProgramNumber
    ),
    PgmClassified AS
    (
        -- Each PGM award classified to an SFN bucket from its CFDA.
        -- The CFDA is zero-padded to NN.NNN first because the warehouse stores
        -- 10.310 as the number 10.31, then joined to the ALN catalog. When the
        -- catalog has no match (or is not yet loaded) the bucket is NULL and the
        -- SFN-mismatch check stays silent.
        SELECT
            pgm.ProjectId,
            pgm.ProjectNumber,
            pgm.SponsorAwardNumber,
            pgm.AwardStartDate,
            pgm.AwardEndDate,
            REPLACE(pgm.SponsorAwardNumber, '-', '') AS AwardKey,
            CASE
                WHEN aln.ProgramNumber IS NULL                                              THEN NULL
                WHEN aln.ProgramNumber = '10.203'                                           THEN 'HATCH'  -- Hatch, matches NIFA 201/202
                WHEN aln.ProgramNumber = '10.202'                                           THEN '203'    -- McIntire-Stennis
                WHEN aln.ProgramNumber IN ('10.205', '10.207')                              THEN '205'    -- Evans-Allen / Animal Health
                WHEN aln.IsNifa = 1                                                         THEN '204'    -- NIFA competitive
                ELSE 'NON-NIFA'
            END AS PgmSfnBucket
        FROM [data].[PGMProjects] pgm
        OUTER APPLY
        (
            SELECT CASE
                WHEN CHARINDEX('.', pgm.Cfda) > 0
                THEN LEFT(pgm.Cfda, CHARINDEX('.', pgm.Cfda))
                     + LEFT(SUBSTRING(pgm.Cfda, CHARINDEX('.', pgm.Cfda) + 1, 10) + '000', 3)
                ELSE pgm.Cfda
            END AS PaddedCfda
        ) p
        LEFT JOIN AlnCatalog aln
            ON aln.ProgramNumber = p.PaddedCfda
    ),
    ActiveCore AS
    (
        -- Active (reportable) NIFA projects, NIFA SFN from the project-number
        -- suffix, joined to AllProjects for award number, title and dates.
        -- ExcludeFromUi = 1 rows are resolved-as-excluded and are dropped.
        SELECT
            a.AccessionNumber,
            a.ProjectNumber AS NifaProjectNumber,
            ap.AwardNumber  AS NifaAwardNumber,
            ap.Title,
            a.ProjectDirector AS ActiveProjectDirector,
            ap.ProjectDirector AS AllProjectDirector,
            ap.Department,
            ap.ProjectStartDate,
            ap.ProjectEndDate,
            CASE WHEN ap.ProjectNumber IS NULL THEN 0 ELSE 1 END AS InAllProjects,
            CASE
                WHEN a.ProjectNumber LIKE '%-H'  THEN '201'
                WHEN a.ProjectNumber LIKE '%-RR' THEN '202'
                WHEN a.ProjectNumber LIKE '%-CG' THEN '204'
                WHEN a.ProjectNumber LIKE '%-AH' THEN '205'
                ELSE 'UNKNOWN'  -- unrecognized suffix: fail closed below, never silently Clean
            END AS NifaSfn
        FROM [data].[ActiveProjects] a
        LEFT JOIN [data].[AllProjects] ap
            ON NULLIF(LTRIM(RTRIM(ap.ProjectNumber)), '') = NULLIF(LTRIM(RTRIM(a.ProjectNumber)), '')
           AND NULLIF(LTRIM(RTRIM(ap.AccessionNumber)), '') = NULLIF(LTRIM(RTRIM(a.AccessionNumber)), '')
        WHERE ISNULL(a.ExcludeFromUi, 0) = 0
    ),
    ActiveWithPgm AS
    (
        SELECT
            ac.AccessionNumber,
            ac.NifaProjectNumber,
            ac.NifaAwardNumber,
            ac.Title,
            COALESCE(NULLIF(ac.ActiveProjectDirector, ''), NULLIF(ac.AllProjectDirector, '')) AS Pi,
            ac.Department,
            ac.ProjectStartDate,
            ac.ProjectEndDate,
            ac.InAllProjects,
            ac.NifaSfn,
            (
                SELECT STRING_AGG(CAST(pc.ProjectNumber AS NVARCHAR(MAX)), ', ')
                FROM PgmClassified pc
                WHERE ac.NifaAwardNumber IS NOT NULL
                  AND pc.AwardKey = REPLACE(ac.NifaAwardNumber, '-', '')
            ) AS PgmProjectNumbers,
            CASE WHEN EXISTS
            (
                SELECT 1 FROM PgmClassified pc
                WHERE ac.NifaAwardNumber IS NOT NULL
                  AND pc.AwardKey = REPLACE(ac.NifaAwardNumber, '-', '')
            ) THEN 1 ELSE 0 END AS HasPgmMatch,
            CASE WHEN EXISTS
            (
                -- any matched PGM award whose bucket conflicts with the NIFA SFN
                -- (201/202 collapse to HATCH; silent when the PGM bucket is NULL)
                SELECT 1 FROM PgmClassified pc
                WHERE ac.NifaAwardNumber IS NOT NULL
                  AND pc.AwardKey = REPLACE(ac.NifaAwardNumber, '-', '')
                  AND pc.PgmSfnBucket IS NOT NULL
                  AND pc.PgmSfnBucket <> CASE ac.NifaSfn
                                             WHEN '201' THEN 'HATCH'
                                             WHEN '202' THEN 'HATCH'
                                             WHEN '204' THEN '204'
                                             WHEN '205' THEN '205'
                                             ELSE '__UNMAPPED__'  -- unknown NIFA SFN never equals a real bucket: fail closed
                                         END
            ) THEN 1 ELSE 0 END AS HasSfnMismatch
        FROM ActiveCore ac
    )

    -- Not in All Projects
    SELECT
        CAST(NifaProjectNumber AS NVARCHAR(20))     AS NifaProject,
        CAST(AccessionNumber AS NVARCHAR(50))       AS Accession,
        CAST(NifaAwardNumber AS NVARCHAR(100))      AS AwardNumber,
        CAST(PgmProjectNumbers AS NVARCHAR(MAX))    AS Ae,
        CAST(Pi AS NVARCHAR(200))                   AS Pi,
        CAST(Department AS NVARCHAR(300))           AS Department,
        CAST(NifaSfn AS NVARCHAR(10))               AS Sfn,
        CAST('Not in All Projects' AS NVARCHAR(30)) AS Status
    FROM ActiveWithPgm
    WHERE InAllProjects = 0

    UNION ALL

    -- Expired (project dates fall outside the cycle window)
    SELECT
        CAST(NifaProjectNumber AS NVARCHAR(20)),
        CAST(AccessionNumber AS NVARCHAR(50)),
        CAST(NifaAwardNumber AS NVARCHAR(100)),
        CAST(PgmProjectNumbers AS NVARCHAR(MAX)),
        CAST(Pi AS NVARCHAR(200)),
        CAST(Department AS NVARCHAR(300)),
        CAST(NifaSfn AS NVARCHAR(10)),
        CAST('Expired' AS NVARCHAR(30))
    FROM ActiveWithPgm
    WHERE InAllProjects = 1
      AND (
            (ProjectEndDate   IS NOT NULL AND ProjectEndDate   < @cycleStart)
         OR (ProjectStartDate IS NOT NULL AND ProjectStartDate > @cycleEnd)
          )

    UNION ALL

    -- No PGM match
    SELECT
        CAST(NifaProjectNumber AS NVARCHAR(20)),
        CAST(AccessionNumber AS NVARCHAR(50)),
        CAST(NifaAwardNumber AS NVARCHAR(100)),
        CAST(PgmProjectNumbers AS NVARCHAR(MAX)),
        CAST(Pi AS NVARCHAR(200)),
        CAST(Department AS NVARCHAR(300)),
        CAST(NifaSfn AS NVARCHAR(10)),
        CAST('No PGM match' AS NVARCHAR(30))
    FROM ActiveWithPgm
    WHERE InAllProjects = 1
      AND HasPgmMatch = 0

    UNION ALL

    -- SFN mismatch
    SELECT
        CAST(NifaProjectNumber AS NVARCHAR(20)),
        CAST(AccessionNumber AS NVARCHAR(50)),
        CAST(NifaAwardNumber AS NVARCHAR(100)),
        CAST(PgmProjectNumbers AS NVARCHAR(MAX)),
        CAST(Pi AS NVARCHAR(200)),
        CAST(Department AS NVARCHAR(300)),
        CAST(NifaSfn AS NVARCHAR(10)),
        CAST('SFN mismatch' AS NVARCHAR(30))
    FROM ActiveWithPgm
    WHERE HasSfnMismatch = 1

    UNION ALL

    -- Clean (fails nothing)
    SELECT
        CAST(NifaProjectNumber AS NVARCHAR(20)),
        CAST(AccessionNumber AS NVARCHAR(50)),
        CAST(NifaAwardNumber AS NVARCHAR(100)),
        CAST(PgmProjectNumbers AS NVARCHAR(MAX)),
        CAST(Pi AS NVARCHAR(200)),
        CAST(Department AS NVARCHAR(300)),
        CAST(NifaSfn AS NVARCHAR(10)),
        CAST('Clean' AS NVARCHAR(30))
    FROM ActiveWithPgm
    WHERE InAllProjects = 1
      AND HasPgmMatch = 1
      AND HasSfnMismatch = 0
      AND NOT (
            (ProjectEndDate   IS NOT NULL AND ProjectEndDate   < @cycleStart)
         OR (ProjectStartDate IS NOT NULL AND ProjectStartDate > @cycleEnd)
          )

    UNION ALL

    -- 204 outside college: a PGM 204 award not tied to any active project
    SELECT
        CAST(NULL AS NVARCHAR(20))                   AS NifaProject,
        CAST(NULL AS NVARCHAR(50))                   AS Accession,
        CAST(pc.SponsorAwardNumber AS NVARCHAR(100)) AS AwardNumber,
        STRING_AGG(CAST(pc.ProjectNumber AS NVARCHAR(MAX)), ', ') AS Ae,
        CAST(NULL AS NVARCHAR(200))                  AS Pi,
        CAST(NULL AS NVARCHAR(300))                  AS Department,
        CAST('204' AS NVARCHAR(10))                  AS Sfn,
        CAST('204 outside college' AS NVARCHAR(30))  AS Status
    FROM PgmClassified pc
    WHERE pc.PgmSfnBucket = '204'
      AND (pc.AwardEndDate IS NULL OR pc.AwardEndDate >= @cycleStart)
      AND (pc.AwardStartDate IS NULL OR pc.AwardStartDate <= @cycleEnd)
      AND NOT EXISTS
      (
          SELECT 1
          FROM [data].[ActiveProjects] a
          JOIN [data].[AllProjects] ap
            ON NULLIF(LTRIM(RTRIM(ap.ProjectNumber)), '') = NULLIF(LTRIM(RTRIM(a.ProjectNumber)), '')
           AND NULLIF(LTRIM(RTRIM(ap.AccessionNumber)), '') = NULLIF(LTRIM(RTRIM(a.AccessionNumber)), '')
          WHERE ISNULL(a.ExcludeFromUi, 0) = 0
            AND ap.AwardNumber IS NOT NULL
            AND REPLACE(ap.AwardNumber, '-', '') = pc.AwardKey
      )
    GROUP BY pc.SponsorAwardNumber;
END
