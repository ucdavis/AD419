CREATE TABLE [dbo].[FIS_SalaryExpenses] (
    [FYr]        INT             NOT NULL,
    [Chart]      VARCHAR (2)     NOT NULL,
    [Org]        CHAR (4)        NOT NULL,
    [Account]    CHAR (7)        NOT NULL,
    [SubAccount] CHAR (5)        NULL,
    [ObjConsol]  CHAR (4)        NULL,
    [Object]     CHAR (4)        NULL,
    [ExpenseSum] DECIMAL (38, 2) NULL
);

