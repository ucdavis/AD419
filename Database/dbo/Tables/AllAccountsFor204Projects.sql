CREATE TABLE [dbo].[AllAccountsFor204Projects] (
    [AccessionNumber]          VARCHAR (7)     NULL,
    [ProjectNumber]            VARCHAR (24)    NULL,
    [AwardNumber]              VARCHAR (20)    NULL,
    [AnnualReportCode]         CHAR (6)        NULL,
    [Chart]                    VARCHAR (2)     NULL,
    [Account]                  CHAR (7)        NULL,
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
    [IsUCD]                    BIT             NULL,
    [Expenses]                 MONEY           NULL,
    [FTE]                      DECIMAL (18, 4) NULL
);

