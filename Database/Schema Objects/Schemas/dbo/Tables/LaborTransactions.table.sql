CREATE TABLE [dbo].[LaborTransactions] (
    [TOE_Name]              VARCHAR (50)    NULL,
    [EID]                   VARCHAR (40)    NOT NULL,
    [Org]                   VARCHAR (4)     NULL,
    [Account]               VARCHAR (7)     NULL,
    [SubAcct]               VARCHAR (5)     NULL,
    [ObjConsol]             VARCHAR (4)     NULL,
    [Object]                VARCHAR (4)     NULL,
    [TitleCd]               VARCHAR (4)     NULL,
    [FinanceDocTypeCd]      VARCHAR (4)     NULL,
    [DosCd]                 VARCHAR (5)     NULL,
    [PayPeriodEndDate]      DATETIME2 (7)   NULL,
    [RateTypeCd]            VARCHAR (1)     NULL,
    [PayRate]               NUMERIC (17, 4) NULL,
    [Amount]                FLOAT           NULL,
    [FringeBenefitSalaryCd] VARCHAR (1)     NULL
);

