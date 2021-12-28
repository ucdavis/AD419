CREATE TABLE [dbo].[Missing204AccountExpenses] (
    [Chart]                 VARCHAR (2)     NOT NULL,
    [Account]               CHAR (7)        NOT NULL,
    [SubAccount]            VARCHAR (5)     NULL,
    [PrincipalInvestigator] VARCHAR (50)    NULL,
    [AnnualReportCode]      CHAR (6)        NULL,
    [OpFundNum]             VARCHAR (6)     NULL,
    [ConsolidationCode]     CHAR (4)        NULL,
    [ObjectCode]            VARCHAR (4)     NULL,
    [TransDocType]          CHAR (4)        NULL,
    [OrgR]                  VARCHAR (4)     NULL,
    [Org]                   CHAR (4)        NOT NULL,
    [Expenses]              DECIMAL (38, 2) NULL,
    [IsExpired]             BIT             NULL,
    [IsUCD]                 BIT             NULL
);



