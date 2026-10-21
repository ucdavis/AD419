/*
Pre-deployment cleanup for objects intentionally removed from the data DACPAC.
*/

-- The segment hierarchy tables were replaced by reading breadcrumbs from
-- ChartSegments. Their rows were seeded copies, so clearing them lets the
-- publish drop the tables without tripping BlockOnPossibleDataLoss.
IF OBJECT_ID(N'[data].[AccountHierarchy]', N'U') IS NOT NULL DELETE FROM [data].[AccountHierarchy];
IF OBJECT_ID(N'[data].[ActivityHierarchy]', N'U') IS NOT NULL DELETE FROM [data].[ActivityHierarchy];
IF OBJECT_ID(N'[data].[DepartmentHierarchy]', N'U') IS NOT NULL DELETE FROM [data].[DepartmentHierarchy];
IF OBJECT_ID(N'[data].[FundHierarchy]', N'U') IS NOT NULL DELETE FROM [data].[FundHierarchy];
IF OBJECT_ID(N'[data].[PurposeHierarchy]', N'U') IS NOT NULL DELETE FROM [data].[PurposeHierarchy];
GO
