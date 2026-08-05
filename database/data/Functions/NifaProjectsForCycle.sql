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
    -- ActiveProjects row. Overrides join directly by AllProjectId. Automatic
    -- AllProjects matches are cycle-filtered, grouped to the lowest
    -- AllProjectId, then joined back so duplicate AllProjects rows never fan
    -- out the result.
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
        CASE
            WHEN COALESCE(overrideProject.AllProjectId, matchedProject.AllProjectId) IS NULL THEN 0
            ELSE 1
        END AS InAllProjects,
        COALESCE(a.SfnOverride, a.DerivedNifaSfn) AS NifaSfn,
        COALESCE(overrideProject.AwardNumber, matchedProject.AwardNumber) AS AwardNumber,
        COALESCE(
            a.PgmAwardKeyOverride,
            overrideProject.AwardKey,
            matchedProject.AwardKey
        ) AS AwardKey,
        COALESCE(overrideProject.Title, matchedProject.Title) AS Title,
        COALESCE(overrideProject.Department, matchedProject.Department) AS Department,
        COALESCE(overrideProject.ProjectDirector, matchedProject.ProjectDirector) AS AllProjectDirector,
        COALESCE(overrideProject.ProjectStartDate, matchedProject.ProjectStartDate) AS ProjectStartDate,
        COALESCE(overrideProject.ProjectEndDate, matchedProject.ProjectEndDate) AS ProjectEndDate
    FROM
    (
        SELECT
            active.*,
            CASE
                WHEN active.ProjectNumber LIKE '%-H'  THEN '201'
                WHEN active.ProjectNumber LIKE '%-RR' THEN '202'
                WHEN active.ProjectNumber LIKE '%-CG' THEN '204'
                WHEN active.ProjectNumber LIKE '%-AH' THEN '205'
                ELSE 'UNKNOWN'
            END AS DerivedNifaSfn
        FROM [data].[ActiveProjects] active
    ) a
    LEFT JOIN [data].[AllProjects] overrideProject
        ON a.AllProjectIdOverride = overrideProject.AllProjectId
    LEFT JOIN
    (
        SELECT
            a.AccessionNumber,
            MIN(x.AllProjectId) AS AllProjectId
        FROM [data].[ActiveProjects] a
        INNER JOIN [data].[AllProjects] x
            ON x.ProjectNumber = a.ProjectNumber
           AND x.AccessionNumber = a.AccessionNumber
           AND (x.ProjectEndDate IS NULL OR x.ProjectEndDate >= @CycleStart)
           AND (x.ProjectStartDate IS NULL OR x.ProjectStartDate <= @CycleEnd)
        WHERE a.AllProjectIdOverride IS NULL
        GROUP BY a.AccessionNumber
    ) matchedProjectId
        ON a.AccessionNumber = matchedProjectId.AccessionNumber
    LEFT JOIN [data].[AllProjects] matchedProject
        ON matchedProjectId.AllProjectId = matchedProject.AllProjectId
);
