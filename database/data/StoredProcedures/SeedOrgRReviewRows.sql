CREATE PROCEDURE [data].[SeedOrgRReviewRows]
AS
BEGIN
    SET NOCOUNT ON;

    -- Inserts rows that need an OrgR decision, with a NULL OrgR. Existing rows
    -- are never updated or deleted here; mappings carry forward across cycles
    -- and are edited only in the OrgR Review stage. Called when Expense Review
    -- completes and whenever the OrgR Review grids load, so it must be
    -- idempotent.

    -- Financial departments classified as included in the AD419 report.
    INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR])
    SELECT sc.[Code], NULL
    FROM [data].[SegmentClassifications] sc
    WHERE sc.[SegmentType] = 'FinancialDepartment'
      AND sc.[IncludeInReport] = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM [data].[OrgRFinancialDepartments] f
          WHERE f.[FinancialDepartment] = sc.[Code]
      );

    -- NIFA department segments present in the current project list.
    INSERT INTO [data].[OrgRNifaDepartments] ([NifaDepartment], [OrgR])
    SELECT DISTINCT SUBSTRING([NifaProjectNumber], 6, 3), NULL
    FROM [data].[Projects] p
    WHERE LEN(p.[NifaProjectNumber]) >= 8
      AND NOT EXISTS
      (
          SELECT 1 FROM [data].[OrgRNifaDepartments] n
          WHERE n.[NifaDepartment] = SUBSTRING(p.[NifaProjectNumber], 6, 3)
      );
END;
