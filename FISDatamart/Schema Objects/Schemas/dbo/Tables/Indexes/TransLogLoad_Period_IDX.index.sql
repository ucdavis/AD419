CREATE NONCLUSTERED INDEX [TransLogLoad_Period_IDX]
    ON [dbo].[TransLogLoad]([FiscalPeriod] ASC)
    INCLUDE([PartitionColumn]);



