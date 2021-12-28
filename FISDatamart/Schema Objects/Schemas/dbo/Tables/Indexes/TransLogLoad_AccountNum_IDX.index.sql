CREATE NONCLUSTERED INDEX [TransLogLoad_AccountNum_IDX]
    ON [dbo].[TransLogLoad]([AccountNum] ASC)
    INCLUDE([PartitionColumn]);



