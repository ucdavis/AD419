CREATE NONCLUSTERED INDEX [TransLogMain_TransChangeDate_DESCIDX]
    ON [dbo].[TransLog]([TransChangeDate] DESC)
    INCLUDE([PartitionColumn]);



