CREATE VIEW [data].[v_ProjXOrgR]
AS
-- One row per project per OrgR screen it appears on. Default rows come from
-- the NIFA project number department segment (characters 6-8) through the
-- reviewed OrgRNifaDepartments mapping. Manual rows are interdepartmental
-- placements added in the OrgR Review stage. A manual row that duplicates a
-- default row is still returned as Manual; select distinct on the first two
-- columns where only the pair matters.
--
-- [data].[Projects] is at NIFA x AE grain: a single project can have several
-- rows sharing the same AccessionNumber and NifaProjectNumber (one per AE
-- project). Both branches join to Projects, so both fan out per AE project;
-- SELECT DISTINCT on each branch collapses those back to one row per
-- (AccessionNumber, NifaProjectNumber, OrgR) triple.
--
-- No LEN >= 8 guard is needed here (unlike SeedOrgRReviewRows) because a
-- department segment is 3 characters: SUBSTRING never returns a value that
-- can match a department code from a project number shorter than that.
SELECT DISTINCT
    p.[AccessionNumber],
    p.[NifaProjectNumber],
    n.[OrgR],
    'Default' AS [Source]
FROM [data].[Projects] p
JOIN [data].[OrgRNifaDepartments] n
    ON n.[NifaDepartment] = SUBSTRING(p.[NifaProjectNumber], 6, 3)
WHERE n.[OrgR] IS NOT NULL

UNION ALL

SELECT DISTINCT
    p.[AccessionNumber],
    p.[NifaProjectNumber],
    a.[OrgR],
    'Manual' AS [Source]
FROM [data].[OrgRProjectAdditions] a
JOIN [data].[Projects] p
    ON p.[AccessionNumber] = a.[AccessionNumber];
