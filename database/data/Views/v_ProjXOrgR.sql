CREATE VIEW [data].[v_ProjXOrgR]
AS
-- One row per project per OrgR screen it appears on. Default rows come from
-- the NIFA project number department segment (characters 6-8) through the
-- reviewed OrgRNifaDepartments mapping. Appointment rows put every non-204
-- project of a PI on each additional OrgR the PI holds an appointment in
-- (OrgRPiAppointments, entered in the OrgR Review stage). A PI appointment
-- is the only way a project lands on a second OrgR. An Appointment row that
-- duplicates a default row is still returned with its own source; select
-- distinct on the first two columns where only the pair matters.
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

-- 204 projects follow their AE project and stay on the default OrgR only.
SELECT DISTINCT
    p.[AccessionNumber],
    p.[NifaProjectNumber],
    a.[OrgR],
    'Appointment' AS [Source]
FROM [data].[OrgRPiAppointments] a
JOIN [data].[Projects] p
    ON p.[UcpEmployeeId] = a.[UcpEmployeeId]
WHERE p.[Sfn] <> '204';
