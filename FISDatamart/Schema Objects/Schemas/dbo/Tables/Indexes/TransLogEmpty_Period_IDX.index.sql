CREATE NONCLUSTERED INDEX [TransLogEmpty_Period_IDX]
    ON [dbo].[TransLogEmpty]([FiscalPeriod] ASC)
    INCLUDE([PartitionColumn]);



