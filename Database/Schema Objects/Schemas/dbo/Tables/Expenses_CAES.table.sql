CREATE TABLE [dbo].[Expenses_CAES] (
    [FYr]        SMALLINT        NOT NULL,
    [Chart]      CHAR (1)        NOT NULL,
    [Org]        CHAR (4)        NOT NULL,
    [Org_R]      CHAR (4)        NULL,
    [Account]    CHAR (7)        NOT NULL,
    [SubAccount] CHAR (5)        NULL,
    [ObjConsol]  CHAR (4)        NULL,
    [ExpenseSum] DECIMAL (11, 2) NOT NULL,
    [idExpense]  INT             IDENTITY (1, 1) NOT NULL
);

