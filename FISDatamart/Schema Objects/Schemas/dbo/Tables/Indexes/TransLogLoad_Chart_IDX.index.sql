CREATE NONCLUSTERED INDEX [TransLogLoad_Chart_IDX]
    ON [dbo].[TransLogLoad]([Chart] ASC)
    INCLUDE([PartitionColumn]);



