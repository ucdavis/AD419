CREATE TYPE [dbo].[AnimalHealthExpensesTableType] AS TABLE (
    [UC_LOC_CD]            VARCHAR (2)     NOT NULL,
    [UC_FUND_NBR]          VARCHAR (6)     NOT NULL,
    [ORG_ID_LEVEL_4]       VARCHAR (4)     NOT NULL,
    [Chart_Num]            VARCHAR (2)     NOT NULL,
    [Acct_Num]             VARCHAR (7)     NOT NULL,
    [Expenses]             MONEY           NULL,
    [Award_Amt]            DECIMAL (15, 2) NULL,
    [Award_Begin_Date]     DATE            NULL,
    [Award_End_Date]       DATE            NULL,
    [CGAWD_PROJ_TTL]       VARCHAR (250)   NULL,
    [SPONSOR_CODE_NAME]    VARCHAR (30)    NULL,
    [PRIMARY_PI_USER_NAME] VARCHAR (124)   NULL,
    [EMAIL_ADDR]           VARCHAR (200)   NULL,
    PRIMARY KEY CLUSTERED ([Chart_Num] ASC, [Acct_Num] ASC));

