CREATE TABLE [data].[StagedAssociations]
(
    -- Auto-association output, one row per (expense, project) share. Rebuilt
    -- whole by BuildAutoAssociations. Modeled on last year's
    -- ad419_stgAssociations; OrgR is already resolved here.
    [Id]              INT            NOT NULL IDENTITY(1, 1),
    [ExpenseId]       INT            NOT NULL,
    [Rule]            NVARCHAR(10)   NOT NULL,  -- 204 | 20x | 220 | FS | CE
    [OrgR]            NVARCHAR(10)   NOT NULL,
    [AeProject]       NVARCHAR(50)   NULL,
    [AccessionNumber] NVARCHAR(7)    NOT NULL,
    [ExpenseSfn]      NVARCHAR(10)   NULL,
    [Expenses]        DECIMAL(19, 4) NOT NULL,
    [Fte]             DECIMAL(9, 6)  NOT NULL,
    [FteSfn]          NVARCHAR(10)   NULL,
    CONSTRAINT [PK_StagedAssociations] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [FK_StagedAssociations_ExpenseSummary] FOREIGN KEY ([ExpenseId]) REFERENCES [data].[ExpenseSummary] ([ExpenseId]),
    CONSTRAINT [UQ_StagedAssociations_Expense_Project_OrgR] UNIQUE ([ExpenseId], [AccessionNumber], [OrgR]),
    CONSTRAINT [CK_StagedAssociations_Rule] CHECK ([Rule] IN (N'204', N'20x', N'220', N'FS', N'CE'))
);
