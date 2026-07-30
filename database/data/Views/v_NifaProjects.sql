CREATE VIEW [data].[v_NifaProjects]
AS
-- The canonical reportable NIFA project list: exactly one row per
-- ActiveProjects row, no matter what. AllProjects enrichment comes through an
-- OUTER APPLY TOP 1 (deterministic on AllProjectId) so duplicate AllProjects
-- rows can never fan a project out and a missing match never drops one.
-- Only AllProjects rows whose dates overlap the current federal fiscal cycle
-- (Oct-Sep, null dates tolerated) count as matches; a project with only
-- date-stale rows keeps its row but gets InAllProjects = 0. The cycle is
-- derived from GETDATE() and mirrors FiscalYearCycle in the server.
-- NIFA SFN comes from the project number suffix; the UNKNOWN fallback fails
-- closed downstream, never silently classified.
SELECT
    a.AccessionNumber,
    a.ProjectNumber,
    CAST(ISNULL(a.ExcludeFromUi, 0) AS BIT) AS ExcludeFromUi,
    a.Is204,
    a.UcpEmployeeId,
    a.UcPathName,
    a.ProjectDirector,
    CASE WHEN ap.AllProjectId IS NULL THEN 0 ELSE 1 END AS InAllProjects,
    CASE
        WHEN a.ProjectNumber LIKE '%-H'  THEN '201'
        WHEN a.ProjectNumber LIKE '%-RR' THEN '202'
        WHEN a.ProjectNumber LIKE '%-CG' THEN '204'
        WHEN a.ProjectNumber LIKE '%-AH' THEN '205'
        ELSE 'UNKNOWN'
    END AS NifaSfn,
    ap.AwardNumber,
    NULLIF(REPLACE(LTRIM(RTRIM(ap.AwardNumber)), '-', ''), '') AS AwardKey,
    ap.Title,
    ap.Department,
    ap.ProjectDirector AS AllProjectDirector,
    ap.ProjectStartDate,
    ap.ProjectEndDate
FROM [data].[ActiveProjects] a
CROSS APPLY
(
    SELECT DATEFROMPARTS(
        CASE WHEN MONTH(GETDATE()) >= 10 THEN YEAR(GETDATE()) ELSE YEAR(GETDATE()) - 1 END,
        10, 1) AS CycleStart
) cs
CROSS APPLY
(
    SELECT DATEADD(DAY, -1, DATEADD(YEAR, 1, cs.CycleStart)) AS CycleEnd
) ce
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
    WHERE NULLIF(LTRIM(RTRIM(x.ProjectNumber)), '') = NULLIF(LTRIM(RTRIM(a.ProjectNumber)), '')
      AND NULLIF(LTRIM(RTRIM(x.AccessionNumber)), '') = NULLIF(LTRIM(RTRIM(a.AccessionNumber)), '')
      AND (x.ProjectEndDate IS NULL OR x.ProjectEndDate >= cs.CycleStart)
      AND (x.ProjectStartDate IS NULL OR x.ProjectStartDate <= ce.CycleEnd)
    ORDER BY x.AllProjectId
) ap;
