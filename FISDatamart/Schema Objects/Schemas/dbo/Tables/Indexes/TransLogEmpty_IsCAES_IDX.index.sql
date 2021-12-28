CREATE NONCLUSTERED INDEX [TransLogEmpty_IsCAES_IDX]
    ON [dbo].[TransLogEmpty]([IsCAESTrans] ASC)
    INCLUDE([PartitionColumn]);



