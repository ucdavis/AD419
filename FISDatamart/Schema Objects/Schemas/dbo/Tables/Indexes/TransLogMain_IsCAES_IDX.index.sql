CREATE NONCLUSTERED INDEX [TransLogMain_IsCAES_IDX]
    ON [dbo].[TransLog]([IsCAESTrans] ASC)
    INCLUDE([PartitionColumn]);



