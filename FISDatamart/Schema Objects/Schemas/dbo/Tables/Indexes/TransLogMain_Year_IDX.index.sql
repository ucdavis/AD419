CREATE NONCLUSTERED INDEX [TransLogMain_Year_IDX]
    ON [dbo].[TransLog]([FiscalYear] ASC)
    INCLUDE([PartitionColumn]);



