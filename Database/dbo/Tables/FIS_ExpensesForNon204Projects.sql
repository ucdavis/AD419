CREATE TABLE [dbo].[FIS_ExpensesForNon204Projects] (
    [Chart]                 VARCHAR (2)  NULL,
    [Account]               VARCHAR (7)  NULL,
    [SubAccount]            VARCHAR (5)  NULL,
    [PrincipalInvestigator] VARCHAR (50) NULL,
    [OpFundNum]             VARCHAR (5)  NULL,
    [ConsolidationCode]     VARCHAR (5)  NULL,
    [ObjectCode]            VARCHAR (5)  NULL,
    [TransDocType]          VARCHAR (5)  NULL,
    [OrgR]                  VARCHAR (5)  NULL,
    [Org]                   VARCHAR (5)  NULL,
    [Expenses]              MONEY        NULL,
    [SFN]                   VARCHAR (5)  NULL
);



