CREATE NONCLUSTERED INDEX [TransLogEmpty_IsPendingTrans]
    ON [dbo].[TransLogEmpty]([IsPendingTrans] ASC)
    INCLUDE([PartitionColumn]);



