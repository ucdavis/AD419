CREATE VIEW [data].[v_PgmProjectSfnBuckets]
AS
-- Each PGM award classified to an SFN bucket from its CFDA (same logic as the
-- PgmClassified CTE in [data].[GetProjectList]). The CFDA is zero-padded to
-- NN.NNN first because the warehouse stores 10.310 as the number 10.31, then
-- joined to the ALN catalog. When the catalog has no match (or is not yet
-- loaded) the bucket is NULL.
SELECT
    pgm.ProjectId,
    pgm.ProjectNumber,
    pgm.SponsorAwardNumber,
    REPLACE(pgm.SponsorAwardNumber, '-', '') AS AwardKey,
    CASE
        WHEN aln.ProgramNumber IS NULL                                              THEN NULL
        WHEN aln.ProgramNumber = '10.203'                                           THEN 'HATCH'  -- Hatch, matches NIFA 201/202
        WHEN aln.ProgramNumber = '10.202'                                           THEN '203'    -- McIntire-Stennis
        WHEN aln.ProgramNumber IN ('10.205', '10.207')                              THEN '205'    -- Evans-Allen / Animal Health
        WHEN aln.FederalAgency030 LIKE 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE%' THEN '204'    -- NIFA competitive
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
LEFT JOIN [data].[AssistanceListingNumbers] aln
    ON aln.ProgramNumber = p.PaddedCfda;
