CREATE TABLE [dbo].[Expenses_CE_Nonsalary] (
    [pk]         INT             IDENTITY (1, 1) NOT NULL,
    [Chart]      CHAR (1)        NULL,
    [Account]    CHAR (7)        NULL,
    [SubAccount] CHAR (5)        NULL,
    [Org]        CHAR (4)        NULL,
    [expend]     DECIMAL (16, 2) NULL
);

