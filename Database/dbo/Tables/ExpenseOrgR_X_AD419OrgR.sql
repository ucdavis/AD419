CREATE TABLE [dbo].[ExpenseOrgR_X_AD419OrgR] (
    [Id]          INT         IDENTITY (1, 1) NOT NULL,
    [Chart]       VARCHAR (2) NULL,
    [ExpenseOrgR] VARCHAR (4) NULL,
	[ExpenseOrg]  VARCHAR (4) NULL,
    [AD419OrgR]   VARCHAR (4) NULL,
    CONSTRAINT [PK_ExpenseOrgR_X_AD419OrgR] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [ExpenseOrgR_X_AD419OrgR_UDX]
    ON [dbo].[ExpenseOrgR_X_AD419OrgR]([Chart] ASC, [ExpenseOrgR] ASC, [ExpenseOrg] ASC, [AD419OrgR] ASC);

