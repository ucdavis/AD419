CREATE NONCLUSTERED INDEX [TransLogEmpty_TransChangeDate_DESCIDX]
    ON [dbo].[TransLogEmpty]([TransChangeDate] DESC)
    INCLUDE([PartitionColumn]);



