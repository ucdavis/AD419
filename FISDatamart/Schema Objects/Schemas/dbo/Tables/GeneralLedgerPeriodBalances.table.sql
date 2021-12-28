CREATE TABLE [dbo].[GeneralLedgerPeriodBalances] (
    [Year]                                   INT             NOT NULL,
    [Period]                                 CHAR (2)        NOT NULL,
    [Chart]                                  VARCHAR (2)     NOT NULL,
    [Account]                                CHAR (7)        NOT NULL,
    [SubAccount]                             CHAR (5)        NOT NULL,
    [ObjectType]                             CHAR (2)        NOT NULL,
    [Object]                                 CHAR (4)        NOT NULL,
    [SubObject]                              CHAR (4)        DEFAULT ('-----') NOT NULL,
    [BalType]                                CHAR (2)        NOT NULL,
    [OrgID]                                  CHAR (4)        NULL,
    [AccountType]                            CHAR (2)        NULL,
    [ObjectConsolidatnNum]                   CHAR (4)        NULL,
    [PeriodBeginningBalance]                 DECIMAL (15, 2) NULL,
    [PeriodTransactionsTotal]                DECIMAL (15, 2) NULL,
    [BalTypeName]                            VARCHAR (40)    NULL,
    [SubFundGroupType]                       CHAR (2)        NULL,
    [YearFinancialBeginningBalance]          DECIMAL (15, 5) NULL,
    [YearContractsAndGrantsBeginningBalance] DECIMAL (15, 2) NULL,
    [LastUpdateDate]                         DATETIME        NULL,
    CONSTRAINT [PK_GeneralLedgerPeriodBalances] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Chart] ASC, [Account] ASC, [SubAccount] ASC, [ObjectType] ASC, [Object] ASC, [SubObject] ASC, [BalType] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial General Ledger Balance For One Fiscal Period: Records in this table contain the previous monthly and current month to-date totals of transactions after the most recent General Ledger transaction against the indicated account/object combination.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year: Identifies a 12 month accounting period', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'Account';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Number: Organization chosen identifier used to subdivide accounts for more detailed analysis and reporting. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'SubAccount';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type Code: Identifies the type of object for which transactions are being summarized as an asset, liability, expenditure, fund balance', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'ObjectType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Number: Identifier used to classify accounting transactions by type. Examples are academic salaries, in-state travel, Reg Fee income.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'Object';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Number: Organization chosen identifier used to subdivide Object identified transaction types within an account. E.g. Meals/incidentals for a Travel object.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'SubObject';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Code: Designates the type of transactions summarized in the balance and transaction total amount fields (actual, budget, encumbrance).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'BalType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'OrgID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Type Code: This code is used to identify the account as income, expenditure, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'AccountType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Consolidation Number: Identifies a group of object levels and their associated object codes for budgeting and Office of the President requirements.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'ObjectConsolidatnNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Period Beginning Balance: The default amount brought forward from the previous year plus the transaction total for previous fiscal periods. Sub Fund Group Types ''B'', ''C'', ''F'', ''H'', ''J'', ''L'', ''P'', ''S'' (and all of Charts ''P'', ''N'' and ''M'') identify balances which use the CG Beginning Balance amount in addition to the Financial Beginning Balance amount for computing the default fiscal period beginning balance.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'PeriodBeginningBalance';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Period Transactions Total Amount: The total of transactions for an account for the fiscal period (to-date if this is the current fiscal period)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'PeriodTransactionsTotal';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Name: Descriptive name given to a balance type code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'BalTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Type Code: Used to group balances by like sub funds. For example, Federal Contracts would be a sub fund group type with a number of associated sub fund groups. Types ''B'', ''C'', ''F'', ''H'', ''J'', ''L'', ''P'', ''S'' (and Charts ''P'', ''N'' and ''M'') identify balances which use the CG Beginning Balance amount in addition to the Financial Beginning Balance amount for the FISCAL_PERIOD_BEGIN_BAL. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'SubFundGroupType';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Period Financial Beginning Balance Amount: The amount calculated as the FISCAL_YEAR_BEGIN_BAL (see the GENERAL_LEDGER_BAL_ALL_PERIOD table) plus all previous FISCAL_PERIOD_TRANS_TOTAL_AMTs. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'YearFinancialBeginningBalance';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year Contracts and Grants Beginning Balance Amount: The amount calculated as the CONTRACTS_AND_GRANTS_BEGIN_BAL (see the GENERAL_LEDGER_BAL_ALL_PERIOD table) plus the FISCAL_YEAR_BEGIN_BAL vfor the year plus all previous FISCAL_PERIOD_TRANS_TOTAL_AMTs. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'YearContractsAndGrantsBeginningBalance';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerPeriodBalances', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

