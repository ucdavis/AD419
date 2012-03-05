CREATE TABLE [dbo].[FFY_2011_SFN_ENTRIES] (
    [Year]              INT          NULL,
    [Chart]             VARCHAR (2)  NOT NULL,
    [Org]               CHAR (4)     NOT NULL,
    [Account]           CHAR (7)     NOT NULL,
    [SubAccount]        CHAR (5)     NULL,
    [ObjConsol]         CHAR (4)     NULL,
    [AwardNum]          VARCHAR (20) NULL,
    [ExpenseSum]        MONEY        NULL,
    [SFN]               VARCHAR (3)  NOT NULL,
    [OrgR]              CHAR (4)     NOT NULL,
    [Accession]         VARCHAR (50) NULL,
    [MatchedByAwardNum] BIT          NULL,
    [QuadNum]           VARCHAR (4)  NULL,
    [IsActive]          BIT          NULL
);

