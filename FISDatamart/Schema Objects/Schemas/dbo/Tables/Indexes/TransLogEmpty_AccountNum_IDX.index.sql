CREATE NONCLUSTERED INDEX [TransLogEmpty_AccountNum_IDX]
    ON [dbo].[TransLogEmpty]([AccountNum] ASC)
    INCLUDE([PartitionColumn]);



