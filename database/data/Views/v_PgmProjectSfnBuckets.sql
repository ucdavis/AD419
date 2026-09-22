CREATE VIEW [data].[v_PgmProjectSfnBuckets]
AS
-- Each PGM award classified to an SFN bucket from its imported CFDA program
-- number. The catalog is deduped by ProgramNumber (imports may carry
-- duplicates); a program counts as NIFA when any of its rows says so. When the
-- catalog has no match (or is not yet loaded) the bucket is NULL.
--
-- PgmSfnBucket is the coarse bucket used by the Project Identification checks
-- (HATCH covers both 201 and 202, NON-NIFA is not resolved). PgmSfn is the
-- concrete report line an expense on this AE project falls under when its
-- fund is classified 'Multiple': the NIFA lines that are unambiguous, plus
-- non-NIFA federal awards mapped by ALN prefix (47.x NSF to 209, other 10.x
-- USDA to 219). HATCH stays NULL here because 201 vs 202 needs the NIFA
-- project list, which v_TransactionSfn consults first.
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
Bucketed AS
(
    SELECT
        pgm.ProjectId,
        pgm.ProjectNumber,
        pgm.SponsorAwardNumber,
        pgm.SponsorAwardKey AS AwardKey,
        aln.ProgramNumber,
        CASE
            WHEN aln.ProgramNumber IS NULL                 THEN NULL
            WHEN aln.ProgramNumber = '10.203'              THEN 'HATCH'  -- Hatch, matches NIFA 201/202
            WHEN aln.ProgramNumber = '10.202'              THEN '203'    -- McIntire-Stennis
            WHEN aln.ProgramNumber IN ('10.205', '10.207') THEN '205'    -- Evans-Allen / Animal Health
            WHEN aln.IsNifa = 1                            THEN '204'    -- NIFA competitive
            ELSE 'NON-NIFA'
        END AS PgmSfnBucket
    FROM [data].[PGMProjects] pgm
    LEFT JOIN AlnCatalog aln
        ON aln.ProgramNumber = pgm.CfdaProgramNumber
)
SELECT
    ProjectId,
    ProjectNumber,
    SponsorAwardNumber,
    AwardKey,
    PgmSfnBucket,
    CAST(CASE
        WHEN PgmSfnBucket IN ('203', '204', '205')                    THEN PgmSfnBucket
        WHEN PgmSfnBucket = 'NON-NIFA' AND ProgramNumber LIKE '47.%'  THEN '209'  -- National Science Foundation
        WHEN PgmSfnBucket = 'NON-NIFA' AND ProgramNumber LIKE '10.%'  THEN '219'  -- USDA outside NIFA
        ELSE NULL
    END AS NVARCHAR(10)) AS PgmSfn
FROM Bucketed;
