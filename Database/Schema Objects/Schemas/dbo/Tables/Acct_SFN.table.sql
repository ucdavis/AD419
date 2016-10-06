CREATE TABLE [dbo].[Acct_SFN] (
    [chart]   CHAR (1)     NOT NULL,
    [acct_id] CHAR (7)     NOT NULL,
    [isCE]    TINYINT      NOT NULL,
    [org]     CHAR (4)     NOT NULL,
    [SFN]     CHAR (10)    NULL,
    [SFNsCt]  SMALLINT     NULL,
    [SFNs]    VARCHAR (50) NULL,
    CONSTRAINT [PK_Acct_SFN_1] PRIMARY KEY CLUSTERED ([chart] ASC, [acct_id] ASC, [isCE] ASC, [org] ASC)
);



