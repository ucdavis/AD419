CREATE TABLE [dbo].[LaborBalAllPeriods] (
    [EID]                VARCHAR (40)    NOT NULL,
    [ORG]                VARCHAR (4)     NULL,
    [ACCOUNT]            VARCHAR (7)     NOT NULL,
    [SUBACCT]            VARCHAR (5)     NOT NULL,
    [OBJCONSOL]          VARCHAR (4)     NULL,
    [TITLECD]            VARCHAR (4)     NOT NULL,
    [FINOBJ_FRNGSLRY_CD] VARCHAR (1)     NULL,
    [AMOUNT]             NUMERIC (19, 2) NULL
);

