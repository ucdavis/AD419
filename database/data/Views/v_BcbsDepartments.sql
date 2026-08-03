CREATE VIEW [data].[v_BcbsDepartments]
AS
-- Financial department codes under the BCBS00C parent department, a level C
-- node (ParentLevel2Code) per the code suffix convention. BCBS expenses are
-- only reportable on fund 13U02 (or via a 204 project), so the AE import
-- limits its BCBS arm to these codes.
SELECT [Code]
FROM [data].[ChartSegments]
WHERE [SegmentName] = 'FinancialDepartment'
  AND [ParentLevel2Code] = 'BCBS00C';
