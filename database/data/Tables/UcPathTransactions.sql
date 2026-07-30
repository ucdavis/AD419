CREATE TABLE [data].[UcPathTransactions]
(
    -- Composite natural key from the source: journal id, journal line, addl seq,
    -- emplid, empl_rcd, erncd ('XXX' for fringe rows), run id.
    [LaborTransactionId]     NVARCHAR(125)  NOT NULL,

    -- Chart string segments (column names aligned with AETransactions for a future
    -- union). Warehouse profiling (salary and fringe views, 2026-07) shows every
    -- segment except Program fully populated on the filtered population, so only
    -- Program stays nullable. The source encodes empty as a blank string, so the
    -- import must trim and blank-to-NULL on the way in for the constraints to mean
    -- anything.
    [Entity]                 NVARCHAR(50)   NOT NULL,
    [Fund]                   NVARCHAR(50)   NOT NULL,
    [FinancialDepartment]    NVARCHAR(50)   NOT NULL,
    [ParentDepartment]       NVARCHAR(50)   NOT NULL,
    [Account]                NVARCHAR(50)   NOT NULL,
    [Purpose]                NVARCHAR(50)   NOT NULL,
    [Program]                NVARCHAR(50)   NULL,
    [Project]                NVARCHAR(50)   NOT NULL,
    [Activity]               NVARCHAR(50)   NOT NULL,

    [FinanceDocTypeCd]       NVARCHAR(4)    NULL,
    -- Components of the natural key are required.
    [ErnCode]                NVARCHAR(3)    NOT NULL,   -- ERNCD for salary rows, 'XXX' for fringe rows (source ERNCD is blank on most fringe)
    [EmployeeId]             NVARCHAR(10)   NOT NULL,
    [EmployeeName]           NVARCHAR(100)  NULL,
    [PositionNumber]         NVARCHAR(8)    NOT NULL,   -- rare source rows without one are excluded at import
    [EffDt]                  DATETIME2(7)   NULL,
    [JobCode]                NVARCHAR(4)    NULL,       -- blank at source for many rows; backfilled by the title-code step
    [RateTypeCd]             NVARCHAR(1)    NULL,
    [Hours]                  DECIMAL(18, 6) NOT NULL,   -- 0 on fringe rows (source fringe view has no hours)
    [Amount]                 DECIMAL(19, 4) NOT NULL,
    [PayRate]                DECIMAL(17, 4) NULL,       -- amount/hours; undefined on fringe rows
    [CalculatedFte]          DECIMAL(9, 6)  NOT NULL,   -- hours / hours in federal fiscal year (2088 or 2096); 0 on fringe rows
    [PayPeriodEndDate]       DATETIME2(7)   NOT NULL,   -- authoritative date for cycle-window logic (fiscal year/period unreliable on corrections)
    [FringeBenefitSalaryCd]  NVARCHAR(1)    NOT NULL,   -- 'S' salary, 'F' fringe (assigned by the import per source view)
    [PaidPercent]            DECIMAL(7, 4)  NULL,       -- salary rows only; source fringe view has no percent columns
    [ErnDerivedPercent]      DECIMAL(7, 4)  NULL,       -- salary rows only
    [FiscalYear]             INT            NOT NULL,   -- PeopleSoft fiscal bookkeeping, kept for QA totals by period
    [Period]                 NVARCHAR(2)    NOT NULL,
    [EmpRcd]                 SMALLINT       NOT NULL,
    [EffSeq]                 SMALLINT       NULL,

    -- Persisted exclusions for rules not owned by step 2 classification.
    -- NULL = not yet classified (fails closed downstream).
    [ExcludedByDate]         BIT            NULL,
    [AccountNotInAE]         BIT            NULL,

    [LoadedAt]               DATETIME2(3)   NULL CONSTRAINT [DF_UcPathTransactions_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_UcPathTransactions] PRIMARY KEY CLUSTERED ([LaborTransactionId])
);
