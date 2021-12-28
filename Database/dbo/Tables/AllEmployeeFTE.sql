﻿CREATE TABLE [dbo].[AllEmployeeFTE] (
    [EmployeeName]      VARCHAR (100)    NULL,
    [EmployeeID]        VARCHAR (40)     NULL,
    [PayPeriodEndDate]  DATETIME2 (7)    NULL,
    [TitleCd]           VARCHAR (4)      NULL,
    [Chart]             VARCHAR (2)      NULL,
    [Org]               VARCHAR (4)      NULL,
    [ExcludedByAccount] BIT              NULL,
    [Account]           VARCHAR (7)      NULL,
    [ObjConsol]         VARCHAR (4)      NULL,
    [FinanceDocTypeCd]  VARCHAR (4)      NULL,
    [DosCd]             VARCHAR (3)      NULL,
    [AnnualReportCode]  VARCHAR (6)      NULL,
    [ExcludedByARC]     BIT              NULL,
    [ExcludedByOrg]     BIT              NULL,
    [Payrate]           NUMERIC (17, 4)  NULL,
    [Amount]            MONEY            NULL,
    [FTE]               NUMERIC (38, 19) NULL,
    [RateTypeCd]        VARCHAR (3)      NULL,
    [ProjectNumber]     VARCHAR (24)     NULL,
    [InclFTE]           NUMERIC (38, 19) NULL,
    [FTE_SFN]           CHAR (3)         NOT NULL,
    [OrgR]              VARCHAR (4)      NULL
);



