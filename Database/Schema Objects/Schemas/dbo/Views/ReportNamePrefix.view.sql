CREATE VIEW ReportNamePrefix
AS
SELECT        [ParamValue] AS AdminUnit
FROM            [dbo].[ParamNameAndValue]
WHERE        [ParamName] = 'FinalReportTablesNamePrefix'
UNION ALL
SELECT        [ParamValue]
FROM            [dbo].[ParamNameAndValue] AS AdminUnit
WHERE        [ParamName] = 'AllTableNamePrefix'
UNION ALL
SELECT        'ADNO' AS AdminUnit
UNION ALL
SELECT        [OrgR] AS AdminUnit
FROM            [dbo].ReportingOrg
WHERE        [IsAdminCluster] = 1 AND [IsActive] = 1

GO



GO


