CREATE NONCLUSTERED INDEX [TransLogMain_IsPendingTrans]
    ON [dbo].[TransLog]([IsPendingTrans] ASC)
    INCLUDE([PartitionColumn]);



