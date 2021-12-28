CREATE NONCLUSTERED INDEX [TransLogMain_OPFund_IDX]
    ON [dbo].[TransLog]([OPFund] ASC)
    INCLUDE([PartitionColumn]);



