CREATE NONCLUSTERED INDEX [TransLogMain_Chart_IDX]
    ON [dbo].[TransLog]([Chart] ASC)
    INCLUDE([PartitionColumn]);



