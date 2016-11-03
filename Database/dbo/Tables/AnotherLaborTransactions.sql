CREATE TABLE [dbo].[AnotherLaborTransactions] (
    [Chart]                 VARCHAR (2)     NULL,
    [Account]               VARCHAR (7)     NULL,
    [SubAccount]            VARCHAR (5)     NULL,
    [Org]                   VARCHAR (4)     NULL,
    [ObjConsol]             VARCHAR (4)     NULL,
    [FinanceDocTypeCd]      VARCHAR (4)     NULL,
    [DosCd]                 VARCHAR (3)     NULL,
    [EmployeeID]            VARCHAR (40)    NULL,
    [EmployeeName]          VARCHAR (100)   NULL,
    [TitleCd]               VARCHAR (4)     NULL,
    [RateTypeCd]            VARCHAR (1)     NULL,
    [Payrate]               NUMERIC (17, 4) NULL,
    [Amount]                MONEY           NULL,
    [PayPeriodEndDate]      DATETIME2 (7)   NULL,
    [FringeBenefitSalaryCd] VARCHAR (1)     NULL,
    [AnnualReportCode]      VARCHAR (6)     NULL,
    [ExcludedByARC]         BIT             NULL,
    [ExcludedByOrg]         BIT             NULL,
    [ExcludedByAccount]     BIT             NULL,
    [ExcludedByObjConsol]   BIT             NULL,
    [ReportingYear]         INT             NULL
);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_EmpName_EmpId_CVIDX]
    ON [dbo].[AnotherLaborTransactions]([EmployeeName] ASC)
    INCLUDE([EmployeeID]);

