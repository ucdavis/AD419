CREATE TABLE [dbo].[Expenses_Field_Stations] (
    [Org_R]                 CHAR (4)        NOT NULL,
    [Accession]             CHAR (7)        NOT NULL,
    [Expense]               DECIMAL (16, 2) NOT NULL,
    [Project_Leader]        VARCHAR (50)    NULL,
    [idFieldStationExpense] INT             IDENTITY (1, 1) NOT NULL
);

