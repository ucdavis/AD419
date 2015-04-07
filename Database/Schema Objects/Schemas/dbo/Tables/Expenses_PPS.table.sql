CREATE TABLE [dbo].[Expenses_PPS] (
    [Org_R]          CHAR (4)     NULL,
    [Employee_ID]    CHAR (9)     NOT NULL,
    [TOE_Name]       VARCHAR (50) NULL,
    [TitleCd]        CHAR (4)     NULL,
    [Account]        CHAR (7)     NOT NULL,
    [SubAcct]        VARCHAR (5)  NULL,
    [ObjConsol]      CHAR (4)     NULL,
    [Object]         CHAR (4)     NULL,
    [Expenses]       MONEY        NULL,
    [FTE]            REAL         NULL,
    [idExpenses_PPS] INT          IDENTITY (1, 1) NOT NULL
);



