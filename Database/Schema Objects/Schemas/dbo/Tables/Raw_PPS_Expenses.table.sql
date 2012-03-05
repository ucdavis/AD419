CREATE TABLE [dbo].[Raw_PPS_Expenses] (
    [TOE_NAME]      NVARCHAR (50) NULL,
    [EID]           CHAR (9)      NULL,
    [Org]           CHAR (4)      NULL,
    [Account]       CHAR (7)      NULL,
    [SubAcct]       CHAR (5)      NULL,
    [ObjConsol]     CHAR (4)      NULL,
    [TitleCd]       CHAR (4)      NULL,
    [Salary]        REAL          NULL,
    [Benefits]      REAL          NULL,
    [FTE]           REAL          NULL,
    [idPPS_TOE_Raw] INT           IDENTITY (1, 1) NOT NULL
);

