CREATE NONCLUSTERED INDEX [TransLogMain_Level3Org_IDX]
    ON [dbo].[TransLog]([Level3_OrgCode] ASC)
    INCLUDE([PartitionColumn]);



