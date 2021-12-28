CREATE TABLE [dbo].[ErsOrganization] (
    [OrgCode]       NUMERIC (9)   NOT NULL,
    [ParentOrgCode] NUMERIC (38)  NULL,
    [OrgId]         NCHAR (6)     NOT NULL,
    [ParentOrgId]   NCHAR (6)     NULL,
    [OrgName]       NVARCHAR (50) NOT NULL
);

