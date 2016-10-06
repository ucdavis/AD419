CREATE TABLE [dbo].[PPS_ExpensesForNon204Projects] (
    [Chart]                 VARCHAR (2)     NULL,
    [Account]               VARCHAR (7)     NULL,
    [SubAccount]            VARCHAR (5)     NULL,
    [PrincipalInvestigator] VARCHAR (50)    NULL,
    [ObjConsol]             VARCHAR (4)     NULL,
    [FinanceDocTypeCd]      VARCHAR (4)     NULL,
    [DosCd]                 VARCHAR (3)     NULL,
    [OrgR]                  VARCHAR (4)     NULL,
    [Org]                   VARCHAR (4)     NULL,
    [EmployeeID]            VARCHAR (40)    NULL,
    [EmployeeName]          VARCHAR (100)   NULL,
    [TitleCd]               VARCHAR (4)     NULL,
    [RateTypeCd]            VARCHAR (1)     NULL,
    [Payrate]               NUMERIC (17, 4) NULL,
    [Amount]                MONEY           NULL,
    [FringeBenefitSalaryCd] VARCHAR (1)     NULL,
    [AnnualReportCode]      VARCHAR (6)     NULL,
    [FTE]                   DECIMAL (18, 4) NULL,
    [SFN]                   VARCHAR (5)     NULL
);

