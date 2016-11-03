CREATE TABLE [dbo].[UFY_FFY_FIS_Expenses] (
    [Id]                    INT          IDENTITY (1, 1) NOT NULL,
    [Chart]                 VARCHAR (2)  NULL,
    [Account]               VARCHAR (7)  NULL,
    [SubAccount]            VARCHAR (5)  NULL,
    [PrincipalInvestigator] VARCHAR (50) NULL,
    [AnnualReportCode]      VARCHAR (6)  NULL,
    [OpFundNum]             VARCHAR (5)  NULL,
    [ConsolidationCode]     VARCHAR (5)  NULL,
    [TransDocType]          VARCHAR (4)  NULL,
    [OrgR]                  VARCHAR (4)  NULL,
    [Org]                   VARCHAR (4)  NULL,
    [Expenses]              MONEY        NULL
);

