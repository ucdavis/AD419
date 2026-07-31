CREATE VIEW [data].[v_BcbsDepartments]
AS
-- Financial department codes under the BCBS00C parent department. BCBS
-- expenses are only reportable on fund 13U02 (or via a 204 project), so the
-- AE import limits its BCBS arm to these codes.
SELECT [Code]
FROM [data].[ChartSegments]
WHERE [SegmentName] = 'FinancialDepartment'
  AND ([ParentLevel0Code] = 'BCBS00C'
    OR [ParentLevel1Code] = 'BCBS00C'
    OR [ParentLevel2Code] = 'BCBS00C'
    OR [ParentLevel3Code] = 'BCBS00C'
    OR [ParentLevel4Code] = 'BCBS00C'
    OR [ParentLevel5Code] = 'BCBS00C');
