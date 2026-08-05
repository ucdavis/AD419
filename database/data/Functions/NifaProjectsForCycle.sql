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
        COALESCE(a.SfnOverride, derived.NifaSfn) AS NifaSfn,
        ap.AwardNumber,
        COALESCE(
            a.PgmAwardKeyOverride,
            ap.AwardKey
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
            x.AwardKey,
            x.Title,
            x.Department,
            x.ProjectDirector,
            x.ProjectStartDate,
            x.ProjectEndDate
        FROM [data].[AllProjects] x
        WHERE a.AllProjectIdOverride IS NOT NULL
          AND x.AllProjectId = a.AllProjectIdOverride
        ORDER BY x.AllProjectId
    ) overrideProject
    OUTER APPLY
    (
        SELECT TOP 1
            x.AllProjectId,
            x.AwardNumber,
            x.AwardKey,
            x.Title,
            x.Department,
            x.ProjectDirector,
            x.ProjectStartDate,
            x.ProjectEndDate
        FROM [data].[AllProjects] x
        WHERE a.AllProjectIdOverride IS NULL
          AND x.ProjectNumber = a.ProjectNumber
          AND x.AccessionNumber = a.AccessionNumber
          AND (x.ProjectEndDate IS NULL OR x.ProjectEndDate >= @CycleStart)
          AND (x.ProjectStartDate IS NULL OR x.ProjectStartDate <= @CycleEnd)
        ORDER BY x.AllProjectId
    ) matchedProject
    OUTER APPLY
    (
        SELECT
            COALESCE(overrideProject.AllProjectId, matchedProject.AllProjectId) AS AllProjectId,
            COALESCE(overrideProject.AwardNumber, matchedProject.AwardNumber) AS AwardNumber,
            COALESCE(overrideProject.Title, matchedProject.Title) AS Title,
            COALESCE(overrideProject.Department, matchedProject.Department) AS Department,
            COALESCE(overrideProject.ProjectDirector, matchedProject.ProjectDirector) AS ProjectDirector,
            COALESCE(overrideProject.ProjectStartDate, matchedProject.ProjectStartDate) AS ProjectStartDate,
            COALESCE(overrideProject.ProjectEndDate, matchedProject.ProjectEndDate) AS ProjectEndDate,
            COALESCE(overrideProject.AwardKey, matchedProject.AwardKey) AS AwardKey
    ) ap
);
