CREATE TABLE [dbo].[ProjectPI] (
    [OrgR]             VARCHAR (4)    NULL,
    [Inv1]             VARCHAR (100)  NULL,
    [PI]               VARCHAR (8000) NULL,
    [LastName]         VARCHAR (100)  NULL,
    [FirstName]        VARCHAR (50)   NULL,
    [FirstInitial]     CHAR (1)       NULL,
    [EmployeeID]       VARCHAR (10)   NULL,
    [IsExistingRecord] BIT            NULL,
    [LastUpdateDate]   DATETIME2 (7)  NULL
);

