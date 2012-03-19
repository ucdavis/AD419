ALTER TABLE [dbo].[GeneralLedgerPeriodBalances]
    ADD CONSTRAINT [PK_GeneralLedgerPeriodBalances] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Chart] ASC, [Account] ASC, [SubAccount] ASC, [ObjectType] ASC, [Object] ASC, [SubObject] ASC, [BalType] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

