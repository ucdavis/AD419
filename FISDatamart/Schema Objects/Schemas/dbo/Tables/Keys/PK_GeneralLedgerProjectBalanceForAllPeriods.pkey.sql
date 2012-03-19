ALTER TABLE [dbo].[GeneralLedgerProjectBalanceForAllPeriods]
    ADD CONSTRAINT [PK_GeneralLedgerProjectBalanceForAllPeriods] PRIMARY KEY CLUSTERED ([Year] ASC, [Chart] ASC, [OrgID] ASC, [Account] ASC, [SubAccount] ASC, [Object] ASC, [SubObject] ASC, [Project] ASC, [BalType] ASC, [ObjectType] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

