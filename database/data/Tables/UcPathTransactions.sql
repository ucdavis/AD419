CREATE TABLE [data].[UcPathTransactions]
(
    -- Composite natural key from the source: journal id, journal line, addl seq,
    -- emplid, empl_rcd, erncd ('XXX' for fringe rows), run id.
    [LaborTransactionId]     NVARCHAR(125)  NOT NULL,

    -- Chart string segments (column names aligned with AETransactions for a future union)
    [Entity]                 NVARCHAR(50)   NULL,
    [Fund]                   NVARCHAR(50)   NULL,
    [FinancialDepartment]    NVARCHAR(50)   NULL,
    [ParentDepartment]       NVARCHAR(50)   NULL,
    [Account]                NVARCHAR(50)   NULL,
    [Purpose]                NVARCHAR(50)   NULL,
    [Program]                NVARCHAR(50)   NULL,
    [Project]                NVARCHAR(50)   NULL,
    [Activity]               NVARCHAR(50)   NULL,

    [FinanceDocTypeCd]       NVARCHAR(4)    NULL,
    [DosCode]                NVARCHAR(3)    NULL,       -- ERNCD for salary rows, 'XXX' for fringe rows
    [EmployeeId]             NVARCHAR(10)   NULL,
    [EmployeeName]           NVARCHAR(100)  NULL,
    [PositionNumber]         NVARCHAR(8)    NULL,
    [EffDt]                  DATETIME2(7)   NULL,
    [JobCode]                NVARCHAR(4)    NULL,
    [RateTypeCd]             NVARCHAR(1)    NULL,
    [Hours]                  DECIMAL(18, 6) NULL,
    [Amount]                 DECIMAL(19, 4) NULL,
    [PayRate]                DECIMAL(17, 4) NULL,
    [CalculatedFte]          DECIMAL(9, 6)  NULL,       -- hours / hours in federal fiscal year (2088 or 2096)
    [PayPeriodEndDate]       DATETIME2(7)   NULL,       -- authoritative date for cycle-window logic (fiscal year/period unreliable on corrections)
    [FringeBenefitSalaryCd]  NVARCHAR(1)    NULL,       -- 'S' salary, 'F' fringe
    [PaidPercent]            DECIMAL(7, 4)  NULL,
    [ErnDerivedPercent]      DECIMAL(7, 4)  NULL,
    [FiscalYear]             INT            NULL,       -- PeopleSoft fiscal bookkeeping, kept for QA totals by period
    [Period]                 NVARCHAR(2)    NULL,
    [EmpRcd]                 SMALLINT       NULL,
    [EffSeq]                 SMALLINT       NULL,

    -- Persisted exclusions for rules not owned by step 2 classification.
    -- NULL = not yet classified (fails closed downstream).
    [ExcludedByDate]         BIT            NULL,
    [AccountNotInAE]         BIT            NULL,

    [LoadedAt]               DATETIME2(3)   NULL CONSTRAINT [DF_UcPathTransactions_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_UcPathTransactions] PRIMARY KEY CLUSTERED ([LaborTransactionId])
);
