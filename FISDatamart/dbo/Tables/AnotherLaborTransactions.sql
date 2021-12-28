CREATE TABLE [dbo].[AnotherLaborTransactions] (
    [LaborTransactionId]    VARCHAR (125)   NOT NULL,
    [Chart]                 VARCHAR (2)     NULL,
    [Account]               VARCHAR (7)     NULL,
    [SubAccount]            VARCHAR (5)     NULL,
    [Org]                   VARCHAR (4)     NULL,
    [ObjConsol]             VARCHAR (4)     NULL,
    [Object]                VARCHAR (4)     NOT NULL,
    [FinanceDocTypeCd]      VARCHAR (4)     NULL,
    [DosCd]                 VARCHAR (3)     NULL,
    [EmployeeID]            VARCHAR (10)    NULL,
    [PPS_ID]                VARCHAR (9)     NULL,
    [EmployeeName]          VARCHAR (100)   NULL,
    [POSITION_NBR]          NVARCHAR (8)    NULL,
    [EFFDT]                 DATETIME2 (7)   NULL,
    [TitleCd]               VARCHAR (4)     NULL,
    [RateTypeCd]            VARCHAR (10)    NULL,
    [Hours]                 NUMERIC (38, 2) NOT NULL,
    [Amount]                NUMERIC (38, 2) NULL,
    [Payrate]               NUMERIC (18, 3) NULL,
    [CalculatedFTE]         NUMERIC (18, 6) NULL,
    [PayPeriodEndDate]      DATETIME2 (7)   NULL,
    [FringeBenefitSalaryCd] VARCHAR (10)    NULL,
    [AnnualReportCode]      VARCHAR (6)     NULL,
    [ExcludedByARC]         BIT             NULL,
    [ExcludedByOrg]         BIT             NULL,
    [ExcludedByAccount]     BIT             NULL,
    [ExcludedByObjConsol]   BIT             NULL,
    [ExcludedByDOS]         BIT             NULL,
    [IncludeInFTECalc]      BIT             NULL,
    [ReportingYear]         INT             NOT NULL,
    [School]                VARCHAR (10)    NULL,
    [OrgId]                 VARCHAR (4)     NULL,
    [PAID_PERCENT]          NUMERIC (38, 4) NULL,
    [ERN_DERIVED_PERCENT]   NUMERIC (38, 6) NULL,
    [IsAES]                 BIT             NULL,
    [LastUpdateDate]        DATETIME2 (7)   NULL,
    [OldId]                 VARCHAR (125)   NULL,
    [Year]                  INT             NULL,
    [Period]                VARCHAR (2)     NULL,
    [EMP_RCD]               SMALLINT        NULL,
    [EFFSEQ]                SMALLINT        NULL,
    CONSTRAINT [PK_AnotherLaborTransactions] PRIMARY KEY CLUSTERED ([LaborTransactionId] ASC, [ReportingYear] ASC)
);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_ChartAccount_NCLIDX]
    ON [dbo].[AnotherLaborTransactions]([Chart] ASC, [Account] ASC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_ObjConsol]
    ON [dbo].[AnotherLaborTransactions]([ObjConsol] ASC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_DOSCd_NCLIDX]
    ON [dbo].[AnotherLaborTransactions]([DosCd] ASC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_YearPeriod_FringeBenefitSalaryCd_NCLIDX]
    ON [dbo].[AnotherLaborTransactions]([Year] DESC, [Period] DESC)
    INCLUDE([FringeBenefitSalaryCd]);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_LastUpdateDate_NCLIDX]
    ON [dbo].[AnotherLaborTransactions]([LastUpdateDate] DESC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_ReportingYear_NCLINDX]
    ON [dbo].[AnotherLaborTransactions]([ReportingYear] DESC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_FFY2020_caes-elzar_test a_TitleCd_NCLINDX]
    ON [dbo].[AnotherLaborTransactions]([TitleCd] ASC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_FFY2020_caes-elzar_test a_EmployeeId_NCLINDX]
    ON [dbo].[AnotherLaborTransactions]([EmployeeID] ASC);


GO
CREATE NONCLUSTERED INDEX [AnotherLaborTransactions_FFY2020_caes-elzar_test a_ChartOrg_NCLINDX]
    ON [dbo].[AnotherLaborTransactions]([Chart] ASC, [Org] ASC);

