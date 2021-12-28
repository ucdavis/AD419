CREATE NONCLUSTERED INDEX [TransLogMain_SubFundGroupType_IDX]
    ON [dbo].[TransLog]([SubFundGroupType] ASC)
    INCLUDE([PartitionColumn]);



