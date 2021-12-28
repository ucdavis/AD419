CREATE TYPE [dbo].[ProjectSFN_TableType] AS TABLE (
    [Project]   VARCHAR (24)    NULL,
    [Accession] CHAR (7)        NULL,
    [OrgR]      CHAR (4)        NULL,
    [inv1]      VARCHAR (50)    NULL,
    [SFN]       CHAR (3)        NULL,
    [Amt]       DECIMAL (16, 3) NULL,
    [isExpense] BIT             NULL);



