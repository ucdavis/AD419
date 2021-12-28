CREATE NONCLUSTERED INDEX [TransLogMain_Period_IDX]
    ON [dbo].[TransLog]([FiscalPeriod] ASC)
    INCLUDE([PartitionColumn]);



