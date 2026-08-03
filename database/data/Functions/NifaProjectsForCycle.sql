CREATE FUNCTION [data].[NifaProjectsForCycle]
(
    @CycleStart DATE,
    @CycleEnd DATE
)
RETURNS TABLE
AS
RETURN
(
    -- The canonical reportable NIFA project list: exactly one row per
    -- ActiveProjects row, no matter what. AllProjects enrichment comes through
    -- an OUTER APPLY TOP 1 (deterministic on AllProjectId) so duplicate
    -- AllProjects rows can never fan a project out and a missing match never
    -- drops one. Only AllProjects rows whose dates overlap the selected federal
    -- fiscal cycle (Oct-Sep, null dates tolerated) count as automatic matches;
    -- a project with only date-stale rows keeps its row but gets
    -- InAllProjects = 0.
    SELECT
        a.AccessionNumber,
        a.ProjectNumber,
        CAST(ISNULL(a.ExcludeFromUi, 0) AS BIT) AS ExcludeFromUi,
        a.Is204,
        a.Notes,
        a.UcpEmployeeId,
        a.UcPathName,
        a.ProjectDirector,
        a.PdEmailAddress,
        a.AllProjectIdOverride,
        a.PgmAwardKeyOverride,
        a.SfnOverride,
        CASE WHEN ap.AllProjectId IS NULL THEN 0 ELSE 1 END AS InAllProjects,
        COALESCE(NULLIF(LTRIM(RTRIM(a.SfnOverride)), ''), derived.NifaSfn) AS NifaSfn,
        ap.AwardNumber,
        COALESCE(
            NULLIF(REPLACE(LTRIM(RTRIM(a.PgmAwardKeyOverride)), '-', ''), ''),
            NULLIF(REPLACE(LTRIM(RTRIM(ap.AwardNumber)), '-', ''), '')
        ) AS AwardKey,
        ap.Title,
        ap.Department,
        ap.ProjectDirector AS AllProjectDirector,
        ap.ProjectStartDate,
        ap.ProjectEndDate
    FROM [data].[ActiveProjects] a
    CROSS APPLY
    (
        SELECT CASE
            WHEN a.ProjectNumber LIKE '%-H'  THEN '201'
            WHEN a.ProjectNumber LIKE '%-RR' THEN '202'
            WHEN a.ProjectNumber LIKE '%-CG' THEN '204'
            WHEN a.ProjectNumber LIKE '%-AH' THEN '205'
            ELSE 'UNKNOWN'
        END AS NifaSfn
    ) derived
    OUTER APPLY
    (
        SELECT TOP 1
            x.AllProjectId,
            x.AwardNumber,
            x.Title,
            x.Department,
            x.ProjectDirector,
            x.ProjectStartDate,
            x.ProjectEndDate
        FROM [data].[AllProjects] x
        WHERE (
                a.AllProjectIdOverride IS NOT NULL
                AND x.AllProjectId = a.AllProjectIdOverride
            )
            OR (
                a.AllProjectIdOverride IS NULL
                AND NULLIF(LTRIM(RTRIM(x.ProjectNumber)), '') = NULLIF(LTRIM(RTRIM(a.ProjectNumber)), '')
                AND NULLIF(LTRIM(RTRIM(x.AccessionNumber)), '') = NULLIF(LTRIM(RTRIM(a.AccessionNumber)), '')
                AND (x.ProjectEndDate IS NULL OR x.ProjectEndDate >= @CycleStart)
                AND (x.ProjectStartDate IS NULL OR x.ProjectStartDate <= @CycleEnd)
            )
        ORDER BY
            CASE WHEN a.AllProjectIdOverride IS NOT NULL AND x.AllProjectId = a.AllProjectIdOverride THEN 0 ELSE 1 END,
            x.AllProjectId
    ) ap
);
