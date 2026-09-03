-- Financial department (AE chart segment) to OrgR. NULL OrgR = needs review.
-- Rows are seeded by [data].[SeedOrgRReviewRows] and edited in-app; never
-- cleared by imports or workflow resets.
CREATE TABLE [data].[OrgRFinancialDepartments]
(
    [FinancialDepartment] NVARCHAR(50)  NOT NULL,
    [OrgR]                NVARCHAR(10)  NULL,
    CONSTRAINT [PK_OrgRFinancialDepartments] PRIMARY KEY CLUSTERED ([FinancialDepartment]),
    CONSTRAINT [FK_OrgRFinancialDepartments_OrgRs] FOREIGN KEY ([OrgR]) REFERENCES [data].[OrgRs] ([Code])
);
