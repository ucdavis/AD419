CREATE NONCLUSTERED INDEX [TransLogEmpty_Level3Org_IDX]
    ON [dbo].[TransLogEmpty]([Level3_OrgCode] ASC)
    INCLUDE([PartitionColumn]);



