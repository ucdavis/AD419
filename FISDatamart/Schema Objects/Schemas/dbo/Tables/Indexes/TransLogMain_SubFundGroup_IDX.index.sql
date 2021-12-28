CREATE NONCLUSTERED INDEX [TransLogMain_SubFundGroup_IDX]
    ON [dbo].[TransLog]([SubFundGroup] ASC)
    INCLUDE([PartitionColumn]);



