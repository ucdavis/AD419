CREATE TABLE [data].[ExpenseSummary]
(
    -- The association unit: included transactions of the current cycle
    -- grouped like last year's ad419_Transactions_Summary, plus one synthetic
    -- row per Field Station and CE Specialist upload row. Rebuilt whole by
    -- BuildAutoAssociations; ExpenseId is not stable across builds.
    [ExpenseId]           INT            NOT NULL IDENTITY(1, 1),
    [Source]              NVARCHAR(12)   NOT NULL,  -- AE | UCPath | FieldStation | CE
    [OrgR]                NVARCHAR(10)   NOT NULL,
    [Entity]              NVARCHAR(50)   NULL,
    [Project]             NVARCHAR(50)   NULL,      -- AE project; NULL on FieldStation and CE rows
    [Activity]            NVARCHAR(50)   NULL,
    [Fund]                NVARCHAR(50)   NULL,
    [FinancialDepartment] NVARCHAR(50)   NULL,
    [EmployeeId]          NVARCHAR(10)   NULL,
    [EmployeeName]        NVARCHAR(100)  NULL,
    [JobCode]             NVARCHAR(4)    NULL,
    [PiName]              NVARCHAR(200)  NULL,      -- CE rows only
    [AccessionNumber]     NVARCHAR(7)    NULL,      -- FieldStation and CE rows only
    [ExpenseSfn]          NVARCHAR(10)   NULL,
    [FteSfn]              NVARCHAR(10)   NULL,
    [Expenses]            DECIMAL(19, 4) NOT NULL,
    [Fte]                 DECIMAL(9, 6)  NOT NULL,
    [RuleExclusion]       NVARCHAR(30)   NULL,      -- Misclassified204: skipped by every rule, reported read-only
    CONSTRAINT [PK_ExpenseSummary] PRIMARY KEY CLUSTERED ([ExpenseId]),
    CONSTRAINT [CK_ExpenseSummary_Source] CHECK ([Source] IN (N'AE', N'UCPath', N'FieldStation', N'CE'))
);
