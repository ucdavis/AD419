CREATE NONCLUSTERED INDEX [GeneralLedgerPeriodBalances_YearBalTypeYearContractsAndGrantsBeginningBalance_CIDX]
    ON [dbo].[GeneralLedgerPeriodBalances]([Year] ASC, [BalType] ASC, [YearContractsAndGrantsBeginningBalance] ASC)
    INCLUDE([Period], [Chart], [Account]) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0)
    ON [PRIMARY];

