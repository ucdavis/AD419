CREATE TABLE [dbo].[AllAccountsFor204Projects] (
    [AccessionNumber]          VARCHAR (7)     NULL,
    [ProjectNumber]            VARCHAR (24)    NULL,
    [AwardNumber]              VARCHAR (20)    NULL,
    [AnnualReportCode]         CHAR (6)        NULL,
    [Chart]                    VARCHAR (2)     NOT NULL,
    [Account]                  CHAR (7)        NOT NULL,
    [OrgR]                     VARCHAR (4)     NULL,
    [Org]                      CHAR (4)        NULL,
    [SFN]                      VARCHAR (3)     NOT NULL,
    [OpFundNum]                VARCHAR (6)     NULL,
    [ProjectEndDate]           DATETIME2 (7)   NULL,
    [IsExpired]                INT             NOT NULL,
    [ExcludedByARC]            INT             NOT NULL,
    [ExcludedByAccount]        INT             NOT NULL,
    [IsAccountInFinancialData] BIT             NULL,
    [IsAssociable]             BIT             NULL,
    [IsUCD]                    BIT             NOT NULL,
    [Expenses]                 MONEY           NULL,
    [FTE]                      DECIMAL (18, 4) NULL,
    CONSTRAINT [PK_AllAccountsFor204Projects] PRIMARY KEY CLUSTERED ([Chart] ASC, [Account] ASC, [IsExpired] ASC, [ExcludedByAccount] ASC, [IsUCD] ASC)
);




GO
CREATE NONCLUSTERED INDEX [AllAccountsFor204Projects_ChartAccount_NCLIDX]
    ON [dbo].[AllAccountsFor204Projects]([Chart] ASC, [Account] ASC);


GO
CREATE NONCLUSTERED INDEX [AllAccountsFor204Projects__NCLIDX]
    ON [dbo].[AllAccountsFor204Projects]([ExcludedByAccount] ASC, [IsUCD] DESC, [IsExpired] ASC);

