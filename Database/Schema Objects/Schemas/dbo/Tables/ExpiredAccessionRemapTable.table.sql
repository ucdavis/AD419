CREATE TABLE [dbo].[ExpiredAccessionRemapTable] (
    [RemapId]     INT          NULL,
    [ExpenseId]   INT          NULL,
    [Accession]   VARCHAR (50) NULL,
    [ToAccession] VARCHAR (50) NULL,
    [OrgR]        VARCHAR (4)  NULL,
    [Expenses]    FLOAT        NULL,
    [FTE]         FLOAT        NULL,
    [isExpired]   BIT          NULL
);

