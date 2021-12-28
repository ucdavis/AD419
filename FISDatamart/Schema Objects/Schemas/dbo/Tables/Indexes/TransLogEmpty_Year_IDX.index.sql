CREATE NONCLUSTERED INDEX [TransLogEmpty_Year_IDX]
    ON [dbo].[TransLogEmpty]([FiscalYear] ASC)
    INCLUDE([PartitionColumn]);



