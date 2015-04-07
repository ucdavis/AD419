CREATE TABLE [dbo].[FIS_JVExpenses] (
    [Org]        CHAR (4)        NOT NULL,
    [Account]    CHAR (7)        NOT NULL,
    [SubAccount] CHAR (5)        NULL,
    [ObjConsol]  CHAR (4)        NULL,
    [ObjectCode] CHAR (4)        NULL,
    [Expenses]   DECIMAL (38, 2) NULL
);

