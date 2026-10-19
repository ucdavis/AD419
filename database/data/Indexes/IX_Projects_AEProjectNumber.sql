-- v_TransactionInclusion looks up the 204 project for every transaction by AE project number.
-- Without this index SQL Server builds an index spool over Projects on every Expense Review query.
CREATE NONCLUSTERED INDEX [IX_Projects_AEProjectNumber]
    ON [data].[Projects] ([AEProjectNumber])
    INCLUDE ([Is204]);
