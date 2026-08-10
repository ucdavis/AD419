CREATE FUNCTION [data].[ImportBlockingIssueForCycle]
(
    @CycleStart DATE,
    @CycleEnd DATE
)
RETURNS NVARCHAR(200)
AS
BEGIN
    -- The reason an expense import cannot run for the given cycle, or NULL
    -- when it can. The one definition shared by the import trigger endpoint
    -- (rejects the run upfront) and the BuildProjects guard (fails closed if
    -- a run reaches it anyway), so the two can never drift.
    RETURN CASE
        WHEN NOT EXISTS (SELECT 1 FROM [data].[ActiveProjects])
            THEN N'ActiveProjects is empty; complete Project Identification before building the project list.'
        WHEN EXISTS (SELECT 1 FROM [data].[ProjectListForCycle](@CycleStart, @CycleEnd) WHERE [Status] <> 'Clean')
            THEN N'Unresolved project issues exist; resolve them in Project Identification first.'
    END;
END
