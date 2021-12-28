CREATE NONCLUSTERED INDEX [TransLogLoad_IsPendingTrans]
    ON [dbo].[TransLogLoad]([IsPendingTrans] ASC)
    INCLUDE([PartitionColumn]);



