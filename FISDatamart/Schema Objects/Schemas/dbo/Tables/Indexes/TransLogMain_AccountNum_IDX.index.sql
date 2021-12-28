CREATE NONCLUSTERED INDEX [TransLogMain_AccountNum_IDX]
    ON [dbo].[TransLog]([AccountNum] ASC)
    INCLUDE([PartitionColumn]);



