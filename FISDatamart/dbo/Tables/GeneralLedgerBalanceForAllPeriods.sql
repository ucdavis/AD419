CREATE TABLE [dbo].[GeneralLedgerBalanceForAllPeriods] (
    [Year]                               NUMERIC (4)     NOT NULL,
    [Chart]                              NVARCHAR (2)    NOT NULL,
    [OrgId]                              NVARCHAR (4)    NULL,
    [AccountType]                        NVARCHAR (2)    NULL,
    [Account]                            NVARCHAR (7)    NOT NULL,
    [SubAccount]                         NVARCHAR (5)    NOT NULL,
    [ObjectConsolidatnNum]               NVARCHAR (4)    NULL,
    [ObjectType]                         NVARCHAR (2)    NOT NULL,
    [Object]                             NVARCHAR (4)    NOT NULL,
    [SubObject]                          NVARCHAR (4)    NOT NULL,
    [BalanceType]                        NVARCHAR (2)    NOT NULL,
    [BalanceTypeName]                    NVARCHAR (40)   NULL,
    [YearToDateActualAmount]             NUMERIC (15, 2) NULL,
    [FiscalYearBeginningBalance]         NUMERIC (15, 2) NULL,
    [ContractsAndGrantsBeginningBalance] NUMERIC (15, 2) NULL,
    [JulyTransactionsTotalAmount]        NUMERIC (15, 2) NULL,
    [AugustTransactionsTotalAmount]      NUMERIC (15, 2) NULL,
    [SeptemberTransactionsTotalAmount]   NUMERIC (15, 2) NULL,
    [OctoberTransactionsTotalAmount]     NUMERIC (15, 2) NULL,
    [NovemberTransactionsTotalAmount]    NUMERIC (15, 2) NULL,
    [DecemberTransactionsTotalAmount]    NUMERIC (15, 2) NULL,
    [JanuaryTransactionsTotalAmount]     NUMERIC (15, 2) NULL,
    [FebruaryTransactionsTotalAmount]    NUMERIC (15, 2) NULL,
    [MarchTransactionsTotalAmount]       NUMERIC (15, 2) NULL,
    [AprilTransactionsTotalAmount]       NUMERIC (15, 2) NULL,
    [MayTransactionsTotalAmount]         NUMERIC (15, 2) NULL,
    [JuneTransactionsTotalAmount]        NUMERIC (15, 2) NULL,
    [Month13TransactionsTotalAmount]     NUMERIC (15, 2) NULL,
    [LastUpdateDate]                     DATETIME2 (7)   NULL
);


GO
CREATE NONCLUSTERED INDEX [GeneralLedgerBalanceForAllPeriods_YearObjectBalType_CoverIDX]
    ON [dbo].[GeneralLedgerBalanceForAllPeriods]([Year] ASC, [Object] ASC, [BalanceType] ASC)
    INCLUDE([Chart], [Account], [YearToDateActualAmount], [FiscalYearBeginningBalance]);

