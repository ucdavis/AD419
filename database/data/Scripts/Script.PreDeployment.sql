/*
Pre-deployment cleanup for objects intentionally removed from the data DACPAC.

Keep drops here scoped to the [data] schema so SQLPackage does not need broad
DropObjectsNotInSource behavior across the whole database.
*/

IF EXISTS
(
    SELECT 1
    FROM sys.key_constraints kc
    JOIN sys.tables t ON t.object_id = kc.parent_object_id
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'data'
      AND t.name = N'AllProjects'
      AND kc.name = N'UQ_AllProjects_ProjectNumber'
)
BEGIN
    ALTER TABLE [data].[AllProjects]
        DROP CONSTRAINT [UQ_AllProjects_ProjectNumber];
END;
GO
