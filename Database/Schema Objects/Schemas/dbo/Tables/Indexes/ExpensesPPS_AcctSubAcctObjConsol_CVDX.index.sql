﻿CREATE NONCLUSTERED INDEX [ExpensesPPS_AcctSubAcctObjConsol_CVDX]
    ON [dbo].[Expenses_PPS]([Account] ASC, [SubAcct] ASC, [ObjConsol] ASC)
    INCLUDE([Employee_ID], [TOE_Name], [TitleCd], [Expenses], [FTE]) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0)
    ON [PRIMARY];

