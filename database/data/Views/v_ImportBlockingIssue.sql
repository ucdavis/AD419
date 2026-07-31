CREATE VIEW [data].[v_ImportBlockingIssue]
AS
-- Single row whose Issue column is the reason an expense import cannot run,
-- or NULL when it can. The one definition shared by the import trigger
-- endpoint (rejects the run upfront) and the BuildProjects guard (fails
-- closed if a run reaches it anyway), so the two can never drift.
SELECT CASE
    WHEN NOT EXISTS (SELECT 1 FROM [data].[ActiveProjects])
        THEN 'ActiveProjects is empty; complete Project Identification before building the project list.'
    WHEN EXISTS (SELECT 1 FROM [data].[v_ProjectList] WHERE [Status] <> 'Clean')
        THEN 'Unresolved project issues exist; resolve them in Project Identification first.'
END AS [Issue];
