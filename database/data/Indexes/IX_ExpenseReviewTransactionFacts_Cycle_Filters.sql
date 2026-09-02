CREATE NONCLUSTERED INDEX [IX_ExpenseReviewTransactionFacts_Cycle_Filters]
    ON [data].[ExpenseReviewTransactionFacts]
    (
        [CycleStart],
        [CycleEnd],
        [Source],
        [Included],
        [FundCode],
        [FinancialDeptCode],
        [AccountCode],
        [AeProjectCode],
        [AccountingPeriod],
        [Sfn]
    )
    INCLUDE
    (
        [EntityCode],
        [PurposeCode],
        [ProgramCode],
        [ActivityCode],
        [Amount],
        [AccountingPeriodSort]
    );
