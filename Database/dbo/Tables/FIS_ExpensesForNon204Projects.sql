CREATE TABLE [dbo].[FIS_ExpensesForNon204Projects] (
    [Chart]                 VARCHAR (2)  NULL,
    [Account]               VARCHAR (50) NULL,
    [SubAccount]            VARCHAR (5)  NULL,
    [PrincipalInvestigator] VARCHAR (50) NULL,
    [OpFundNum]             VARCHAR (5)  NULL,
    [ConsolidationCode]     VARCHAR (50) NULL,
    [TransDocType]          VARCHAR (4)  NULL,
    [OrgR]                  VARCHAR (50) NULL,
    [Org]                   VARCHAR (50) NULL,
    [Expenses]              MONEY        NULL,
    [SFN]                   VARCHAR (5)  NULL
);

