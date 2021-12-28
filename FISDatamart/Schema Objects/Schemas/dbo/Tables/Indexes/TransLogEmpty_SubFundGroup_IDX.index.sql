CREATE NONCLUSTERED INDEX [TransLogEmpty_SubFundGroup_IDX]
    ON [dbo].[TransLogEmpty]([SubFundGroup] ASC)
    INCLUDE([PartitionColumn]);



