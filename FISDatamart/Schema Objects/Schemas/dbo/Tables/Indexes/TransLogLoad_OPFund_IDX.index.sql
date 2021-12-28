CREATE NONCLUSTERED INDEX [TransLogLoad_OPFund_IDX]
    ON [dbo].[TransLogLoad]([OPFund] ASC)
    INCLUDE([PartitionColumn]);



