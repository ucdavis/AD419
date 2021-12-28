CREATE NONCLUSTERED INDEX [TransLogEmpty_OPFund_IDX]
    ON [dbo].[TransLogEmpty]([OPFund] ASC)
    INCLUDE([PartitionColumn]);



