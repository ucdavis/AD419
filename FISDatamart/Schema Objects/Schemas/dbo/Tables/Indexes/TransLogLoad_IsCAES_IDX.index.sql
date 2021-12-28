CREATE NONCLUSTERED INDEX [TransLogLoad_IsCAES_IDX]
    ON [dbo].[TransLogLoad]([IsCAESTrans] ASC)
    INCLUDE([PartitionColumn]);



