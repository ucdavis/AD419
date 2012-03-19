CREATE NONCLUSTERED INDEX [Trans_ChangeDate_CVIDX]
    ON [dbo].[Trans]([ChangeDate] ASC)
    INCLUDE([PKTrans], [Year], [Period], [Chart], [Account], [SubAccount], [Object], [SubObject], [BalType], [DocType], [DocOrigin], [DocNum], [DocTrackNum], [InitrID], [InitDate], [LineSquenceNumber], [LineDesc], [LineAmount], [Project], [OrgRefNum], [PriorDocTypeNum], [PriorDocOriginCd], [PriorDocNum], [EncumUpdtCd], [CreationDate], [PostDate], [ReversalDate], [SrcTblCd], [OrganizationFK], [AccountsFK], [ObjectsFK], [SubAccountFK], [ProjectFK], [IsCAES]) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0)
    ON [PRIMARY];

