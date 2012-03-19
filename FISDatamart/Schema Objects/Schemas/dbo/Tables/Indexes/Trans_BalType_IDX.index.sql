﻿CREATE NONCLUSTERED INDEX [Trans_BalType_IDX]
    ON [dbo].[Trans]([BalType] ASC)
    INCLUDE([PKTrans], [Year], [Period], [Chart], [OrgID], [Account], [SubAccount], [Object], [SubObject], [DocType], [DocOrigin], [DocNum], [DocTrackNum], [InitrID], [InitDate], [LineSquenceNumber], [LineDesc], [LineAmount], [Project], [OrgRefNum], [PriorDocTypeNum], [PriorDocOriginCd], [PriorDocNum], [EncumUpdtCd], [CreationDate], [PostDate], [ReversalDate], [ChangeDate], [SrcTblCd], [OrganizationFK], [AccountsFK], [ObjectsFK], [SubObjectFK], [SubAccountFK], [ProjectFK], [IsCAES]) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0)
    ON [PRIMARY];

