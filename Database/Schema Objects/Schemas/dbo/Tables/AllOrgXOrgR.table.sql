CREATE TABLE [dbo].[AllOrgXOrgR] (
    [Chart]       CHAR (1)    NOT NULL,
    [Org]         CHAR (4)    NOT NULL,
    [OrgR]        CHAR (4)    NOT NULL,
    [FiscalYear]  INT         NULL,
    [HomeDeptNum] VARCHAR (6) NULL,
    CONSTRAINT [PK_OrgXOrgR] PRIMARY KEY CLUSTERED ([Chart] ASC, [Org] ASC, [OrgR] ASC)
);



