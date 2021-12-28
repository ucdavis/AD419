CREATE NONCLUSTERED INDEX [TransLogLoad_Year_IDX]
    ON [dbo].[TransLogLoad]([FiscalYear] ASC)
    INCLUDE([PartitionColumn]);



