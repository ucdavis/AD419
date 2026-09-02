CREATE TABLE [data].[ExpenseReviewCacheStatus]
(
    [CycleStart] DATE         NOT NULL,
    [CycleEnd]   DATE         NOT NULL,
    [RefreshedAt] DATETIME2(3) NOT NULL,
    [FactRowCount] INT         NOT NULL,
    [ReasonRowCount] INT       NOT NULL,
    CONSTRAINT [PK_ExpenseReviewCacheStatus] PRIMARY KEY CLUSTERED ([CycleStart], [CycleEnd])
);
