CREATE NONCLUSTERED INDEX [TransLogEmpty_Chart_IDX]
    ON [dbo].[TransLogEmpty]([Chart] ASC)
    INCLUDE([PartitionColumn]);



