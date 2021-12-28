CREATE TABLE [dbo].[ErsOrganizationFlat] (
    [OrgCode]       NUMERIC (9) NOT NULL,
    [ParentOrgCode] NUMERIC (9) NOT NULL,
    [OrgLevel]      NUMERIC (9) NOT NULL,
    CONSTRAINT [PK_ErsOrganizationFlat] PRIMARY KEY CLUSTERED ([OrgCode] ASC, [ParentOrgCode] ASC)
);

