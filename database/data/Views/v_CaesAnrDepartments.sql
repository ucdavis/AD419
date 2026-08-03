CREATE VIEW [data].[v_CaesAnrDepartments]
AS
-- Financial department codes under the CAES (AAES00C) or ANR (9AAES0D)
-- parent departments. The parents sit at fixed hierarchy levels, per the code
-- suffix convention: AAES00C is a level C node (ParentLevel2Code) and 9AAES0D
-- is level D (ParentLevel3Code). Drives the AE transaction import's wide net
-- and is reusable by the expense display views.
SELECT [Code]
FROM [data].[ChartSegments]
WHERE [SegmentName] = 'FinancialDepartment'
  AND ([ParentLevel2Code] = 'AAES00C' OR [ParentLevel3Code] = '9AAES0D');
