CREATE NONCLUSTERED INDEX [IX_ExpenseReviewTransactionReasons_Cycle_Code]
    ON [data].[ExpenseReviewTransactionReasons] ([CycleStart], [CycleEnd], [Code], [TransactionId])
    INCLUDE ([Label], [Amount]);
