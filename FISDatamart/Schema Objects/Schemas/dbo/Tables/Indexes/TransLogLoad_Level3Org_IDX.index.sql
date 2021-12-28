CREATE NONCLUSTERED INDEX [TransLogLoad_Level3Org_IDX]
    ON [dbo].[TransLogLoad]([Level3_OrgCode] ASC)
    INCLUDE([PartitionColumn]);



