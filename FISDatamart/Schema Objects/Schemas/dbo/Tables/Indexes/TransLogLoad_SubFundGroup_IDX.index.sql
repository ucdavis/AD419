CREATE NONCLUSTERED INDEX [TransLogLoad_SubFundGroup_IDX]
    ON [dbo].[TransLogLoad]([SubFundGroup] ASC)
    INCLUDE([PartitionColumn]);



