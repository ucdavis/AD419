CREATE VIEW [data].[v_CaesAnrDepartments]
AS
-- Financial department codes under the CAES (AAES00C) or ANR (9AAES0D)
-- parent departments, per the imported chart segment hierarchy. Drives the
-- AE transaction import's wide net and is reusable by the expense display
-- views.
SELECT [Code]
FROM [data].[ChartSegments]
WHERE [SegmentName] = 'FinancialDepartment'
  AND ([ParentLevel0Code] IN ('AAES00C', '9AAES0D')
    OR [ParentLevel1Code] IN ('AAES00C', '9AAES0D')
    OR [ParentLevel2Code] IN ('AAES00C', '9AAES0D')
    OR [ParentLevel3Code] IN ('AAES00C', '9AAES0D')
    OR [ParentLevel4Code] IN ('AAES00C', '9AAES0D')
    OR [ParentLevel5Code] IN ('AAES00C', '9AAES0D'));
