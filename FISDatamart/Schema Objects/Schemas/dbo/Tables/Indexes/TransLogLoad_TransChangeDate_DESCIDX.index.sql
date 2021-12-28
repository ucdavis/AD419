CREATE NONCLUSTERED INDEX [TransLogLoad_TransChangeDate_DESCIDX]
    ON [dbo].[TransLogLoad]([TransChangeDate] DESC)
    INCLUDE([PartitionColumn]);



