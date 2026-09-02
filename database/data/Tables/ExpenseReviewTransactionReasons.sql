CREATE TABLE [data].[ExpenseReviewTransactionReasons]
(
    [CycleStart]    DATE           NOT NULL,
    [CycleEnd]      DATE           NOT NULL,
    [TransactionId] NVARCHAR(160)  NOT NULL,
    [Code]          NVARCHAR(220)  NOT NULL,
    [Label]         NVARCHAR(500)  NOT NULL,
    [Amount]        DECIMAL(19, 4) NULL,
    [RefreshedAt]   DATETIME2(3)   NOT NULL CONSTRAINT [DF_ExpenseReviewTransactionReasons_RefreshedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_ExpenseReviewTransactionReasons] PRIMARY KEY CLUSTERED ([CycleStart], [CycleEnd], [TransactionId], [Code]),
    CONSTRAINT [FK_ExpenseReviewTransactionReasons_Facts] FOREIGN KEY ([CycleStart], [CycleEnd], [TransactionId])
        REFERENCES [data].[ExpenseReviewTransactionFacts] ([CycleStart], [CycleEnd], [TransactionId])
        ON DELETE CASCADE
);
