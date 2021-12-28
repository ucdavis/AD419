CREATE NONCLUSTERED INDEX [TransLogEmpty_SubFundGroupType_IDX]
    ON [dbo].[TransLogEmpty]([SubFundGroupType] ASC)
    INCLUDE([PartitionColumn]);



