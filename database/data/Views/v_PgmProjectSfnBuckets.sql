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
-- fund is classified 'Multiple'. It ports last year's PGM_MasterData SFN rules
-- (first match wins) onto the columns we import. Last year's sponsor LOC
-- clause is left out because the source has no such field, and last year's
-- NIH ALN list (CFDANumImport) is replaced by the catalog agency.
-- Award types with no report line (the PGM FFT codes 21-35) stay NULL.
WITH AlnCatalog AS
(
    SELECT
        ProgramNumber,
        MAX(CASE
            WHEN FederalAgency030 LIKE 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE%' THEN 1
            ELSE 0
        END) AS IsNifa,
        MAX(CASE
            WHEN FederalAgency030 LIKE 'NATIONAL INSTITUTES OF HEALTH%' THEN 1
            ELSE 0
        END) AS IsNih
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
        aln.IsNih,
        pgm.CfdaProgramNumber AS Aln,
        pgm.AwardNumber,
        pgm.AwardType,
        pgm.PrimarySponsorName,
        pgm.FundingSourceName,
        pgm.AwardDescription,
        pgm.FlowThroughPrimarySponsor,
        pgm.FlowThroughFederalAgency,
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
        WHEN AwardNumber IN ('21005', '21006', '21009', '21010')
          OR (AwardDescription LIKE 'HATCH%' AND AwardDescription NOT LIKE '%MULTI STATE%') THEN '201'
        WHEN AwardNumber IN ('21013', '21014', '21015', '21016')
          OR (AwardDescription LIKE 'HATCH%' AND AwardDescription LIKE '%MULTI STATE%')     THEN '202'
        WHEN AwardNumber IN ('21007', '21008')                            THEN '203'
        WHEN AwardNumber IN ('21003', '21004')                            THEN '205'
        -- A Hatch ALN award without a Hatch description: 201 vs 202 needs the
        -- NIFA project list, which v_TransactionSfn consults first.
        WHEN PgmSfnBucket = 'HATCH'                                       THEN NULL
        WHEN FlowThroughPrimarySponsor = 'NATIONAL INSTITUTE FOR FOOD AND AGRICULTURE'
          OR PrimarySponsorName = 'NATIONAL INSTITUTE FOR FOOD AND AGRICULTURE'
          OR FundingSourceName = 'NATIONAL INSTITUTE FOR FOOD AND AGRICULTURE' THEN '204'
        -- Unlike last year, a NIFA program ALN counts as NIFA even when no
        -- sponsor field names NIFA (mostly subawards from other universities).
        WHEN PgmSfnBucket IN ('203', '204', '205')                        THEN '204'
        WHEN Aln LIKE '10.%'
          OR (FlowThroughPrimarySponsor IN ('US DEPARTMENT OF AGRICULTURE MISCELLANEOUS AGENCIES',
                                            'US DEPARTMENT OF AGRICULTURE AGRICULTURAL MARKETING SERVICE')
              AND FlowThroughFederalAgency = 'Y')                         THEN '219'
        WHEN PrimarySponsorName = 'NATIONAL SCIENCE FOUNDATION'
          OR FundingSourceName = 'NATIONAL SCIENCE FOUNDATION'
          OR Aln LIKE '47.%'                                              THEN '209'
        WHEN Aln LIKE '98.%'
          OR FundingSourceName = 'U S AGENCY FOR INTERNATIONAL DEVELOPMENT'
          OR FlowThroughPrimarySponsor = 'U S AGENCY FOR INTERNATIONAL DEVELOPMENT' THEN '308'
        WHEN Aln LIKE '77.%' OR Aln LIKE '81.%'
          OR FundingSourceName = 'DEPARTMENT OF ENERGY WASHINGTON DC'     THEN '310'
        WHEN Aln LIKE '12.%'                                              THEN '311'
        WHEN Aln LIKE '43.%'                                              THEN '314'
        WHEN Aln LIKE '93.%'
          AND (IsNih = 1
            OR FundingSourceName LIKE '%NATIONAL INST%'
            OR FlowThroughPrimarySponsor LIKE '%NATIONAL INST%'
            OR FlowThroughPrimarySponsor LIKE 'NIH%'
            OR FlowThroughPrimarySponsor = 'NATIONAL CANCER INSTITUTE')    THEN '316'
        WHEN Aln LIKE '93.%'                                              THEN '313'
        WHEN PrimarySponsorName LIKE 'US DEPARTMENT OF AGRICULTURE%'
          OR FundingSourceName LIKE 'US DEPARTMENT OF AGRICULTURE%'       THEN '219'
        WHEN LEFT(AwardType, 3) IN ('04-', '05-', '06-', '07-', '08-')
          AND (FlowThroughFederalAgency IS NULL OR FlowThroughFederalAgency = 'N') THEN '223'
        WHEN LEFT(Aln, 3) IN ('11.', '15.', '20.', '66.')
          OR LEFT(AwardType, 3) IN ('01-', '02-')                         THEN '318'
        WHEN LEFT(AwardType, 3) IN ('09-', '10-', '11-', '12-', '13-', '14-',
                                    '15-', '16-', '17-', '18-')           THEN '222'
        ELSE NULL
    END AS NVARCHAR(10)) AS PgmSfn
FROM Bucketed;
