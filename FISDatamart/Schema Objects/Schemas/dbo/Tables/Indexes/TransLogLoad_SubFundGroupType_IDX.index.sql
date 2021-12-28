CREATE NONCLUSTERED INDEX [TransLogLoad_SubFundGroupType_IDX]
    ON [dbo].[TransLogLoad]([SubFundGroupType] ASC)
    INCLUDE([PartitionColumn]);



