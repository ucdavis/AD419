CREATE FUNCTION [data].[ProjectListForCycle]
(
    @CycleStart DATE,
    @CycleEnd DATE
)
RETURNS TABLE
AS
RETURN
(
    WITH IncludedNifa AS
    (
        SELECT
            nv.AccessionNumber,
            nv.ProjectNumber,
            nv.AwardNumber,
            nv.AwardKey,
            nv.Is204,
            nv.Notes,
            COALESCE(NULLIF(nv.ProjectDirector, ''), NULLIF(nv.AllProjectDirector, '')) AS Pi,
            nv.PdEmailAddress,
            nv.UcpEmployeeId,
            nv.UcPathName,
            nv.Department,
            nv.InAllProjects,
            nv.NifaSfn,
            nv.SfnOverride,
            CASE nv.NifaSfn
                WHEN '201' THEN 'HATCH'
                WHEN '202' THEN 'HATCH'
                WHEN '204' THEN '204'
                WHEN '205' THEN '205'
                ELSE '__UNMAPPED__'
            END AS ExpectedPgmSfnBucket
        FROM [data].[NifaProjectsForCycle](@CycleStart, @CycleEnd) nv
        WHERE nv.ExcludeFromUi = 0
    ),
    PgmByProject AS
    (
        SELECT
            nv.AccessionNumber,
            STRING_AGG(CAST(pc.ProjectNumber AS NVARCHAR(MAX)), ', ')
                WITHIN GROUP (ORDER BY pc.ProjectNumber) AS PgmProjectNumbers,
            CASE WHEN COUNT_BIG(pc.ProjectNumber) > 0 THEN 1 ELSE 0 END AS HasPgmMatch,
            MAX(CASE
                -- Any matched PGM award whose bucket conflicts with the NIFA
                -- SFN (201/202 collapse to HATCH; silent when the PGM bucket is
                -- NULL).
                WHEN pc.PgmSfnBucket IS NOT NULL
                     AND pc.PgmSfnBucket <> nv.ExpectedPgmSfnBucket
                THEN 1
                ELSE 0
            END) AS HasSfnMismatch
        FROM IncludedNifa nv
        LEFT JOIN [data].[v_PgmProjectSfnBuckets] pc
            ON pc.AwardKey = nv.AwardKey
        GROUP BY nv.AccessionNumber
    ),
    ActiveWithPgm AS
    (
        SELECT
            nv.AccessionNumber,
            nv.ProjectNumber,
            nv.AwardNumber,
            nv.Is204,
            nv.Notes,
            nv.Pi,
            nv.PdEmailAddress,
            nv.UcpEmployeeId,
            nv.UcPathName,
            nv.Department,
            nv.InAllProjects,
            nv.NifaSfn,
            pgm.PgmProjectNumbers,
            pgm.HasPgmMatch,
            CASE
                WHEN nv.SfnOverride IS NOT NULL THEN 0
                ELSE pgm.HasSfnMismatch
            END AS HasSfnMismatch
        FROM IncludedNifa nv
        LEFT JOIN PgmByProject pgm
            ON pgm.AccessionNumber = nv.AccessionNumber
    )
    -- Each included reportable NIFA project with its Project Identification
    -- status: exactly one row and one status per project. The statuses are
    -- mutually exclusive by construction: a project not in AllProjects has no
    -- award number, so it can never be PGM-matched or SFN-mismatched, and an
    -- SFN mismatch requires a PGM match.
    SELECT
        CAST(ProjectNumber AS NVARCHAR(20))      AS NifaProject,
        CAST(AccessionNumber AS NVARCHAR(50))    AS Accession,
        CAST(AwardNumber AS NVARCHAR(100))       AS AwardNumber,
        CAST(PgmProjectNumbers AS NVARCHAR(MAX)) AS Ae,
        CAST(Is204 AS BIT)                       AS Is204,
        CAST(Notes AS NVARCHAR(MAX))             AS Notes,
        CAST(Pi AS NVARCHAR(200))                AS Pi,
        CAST(PdEmailAddress AS NVARCHAR(320))    AS PdEmailAddress,
        CAST(UcpEmployeeId AS NVARCHAR(8))       AS UcpEmployeeId,
        CAST(UcPathName AS NVARCHAR(200))        AS UcPathName,
        CAST(Department AS NVARCHAR(300))        AS Department,
        CAST(NifaSfn AS NVARCHAR(10))            AS Sfn,
        CAST(CASE
            WHEN InAllProjects = 0                     THEN 'Not in All Projects'
            WHEN NifaSfn = '204' AND HasPgmMatch = 0   THEN 'No PGM match'
            WHEN HasSfnMismatch = 1                    THEN 'SFN mismatch'
            ELSE 'Clean'
        END AS NVARCHAR(30))                     AS [Status]
    FROM ActiveWithPgm
);
