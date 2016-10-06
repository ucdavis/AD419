CREATE TABLE [dbo].[GeneralLedgerProjectBalanceForAllPeriods] (
    [Year]                               INT             NOT NULL,
    [Chart]                              VARCHAR (2)     NOT NULL,
    [OrgID]                              CHAR (4)        NOT NULL,
    [AccountType]                        CHAR (2)        NULL,
    [Account]                            CHAR (7)        NOT NULL,
    [SubAccount]                         CHAR (5)        NOT NULL,
    [ObjectConsolidatnNum]               CHAR (4)        NULL,
    [Object]                             CHAR (4)        NOT NULL,
    [SubObject]                          VARCHAR (5)     NOT NULL,
    [Project]                            VARCHAR (10)    NOT NULL,
    [BalType]                            CHAR (2)        NOT NULL,
    [BalTypeName]                        VARCHAR (40)    NULL,
    [ObjectType]                         CHAR (2)        NOT NULL,
    [SubFundGroupType]                   VARCHAR (2)     NULL,
    [BalanceCreateDate]                  DATETIME        NULL,
    [YearToDateActualBalance]            DECIMAL (15, 2) NULL,
    [FiscalYearBeginningBalance]         DECIMAL (15, 2) NULL,
    [ContractsAndGrantsBeginningBalance] DECIMAL (15, 2) NULL,
    [JulyTransactionsTotalAmount]        DECIMAL (15, 2) NULL,
    [AugustTransactionsTotalAmount]      DECIMAL (15, 2) NULL,
    [SeptemberTransactionsTotalAmount]   DECIMAL (15, 2) NULL,
    [OctoberTransactionsTotalAmount]     DECIMAL (15, 2) NULL,
    [NovemberTransactionsTotalAmount]    DECIMAL (15, 2) NULL,
    [DecemberTransactionsTotalAmount]    DECIMAL (15, 2) NULL,
    [JanuaryTransactionsTotalAmount]     DECIMAL (15, 2) NULL,
    [FebruaryTransactionsTotalAmount]    DECIMAL (15, 2) NULL,
    [MarchTransactionsTotalAmount]       DECIMAL (15, 2) NULL,
    [AprilTransactionsTotalAmount]       DECIMAL (15, 2) NULL,
    [MayTransactionsTotalAmount]         DECIMAL (15, 2) NULL,
    [JuneTransactionsTotalAmount]        DECIMAL (15, 2) NULL,
    [Month13TransactionsTotalAmount]     DECIMAL (15, 2) NULL,
    [LastUpdateDate]                     DATETIME        NULL,
    CONSTRAINT [PK_GeneralLedgerProjectBalanceForAllPeriods] PRIMARY KEY CLUSTERED ([Year] ASC, [Chart] ASC, [OrgID] ASC, [Account] ASC, [SubAccount] ASC, [Object] ASC, [SubObject] ASC, [Project] ASC, [BalType] ASC, [ObjectType] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'GeneralLedgerProjectBalanceForAllPeriods: This record contains the previous monthly and current month to-date totals of transactions after the most recent General Ledger transaction against the indicated account/object/project combination.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year: Identifies a 12 month accounting period', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'OrgID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Type Code: This code is used to identify the account as income, expenditure, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'AccountType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'Account';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Number: Organization chosen identifier used to subdivide accounts for more detailed analysis and reporting. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'SubAccount';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Consolidation Number: Identifies a group of object levels and their associated object codes for budgeting and Office of the President requirements.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'ObjectConsolidatnNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Number: Identifier used to classify accounting transactions by type. Examples are academic salaries, in-state travel, Reg Fee income.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'Object';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub_Object Number: Organization chosen identifier used to subdivide Object identified transaction types within an account. E.g. Meals/incidentals for a Travel object.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'SubObject';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project Number: ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'Project';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Code: Designates the type of transactions summarized in the balance and transaction total amount fields (actual, budget, encumbrance).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'BalType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Name: Descriptive name given to a balance type code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'BalTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type Code: Identifies the type of object for which transactions are being summarized as an asset, liability, expenditure, fund balance', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'ObjectType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Type Code: Used to group like sub funds. For example, Federal Contracts would be a sub fund group type with a number of associated sub fund groups. Types ''B'', ''C'', ''E'', ''F'', ''H'', ''J'', ''L'', ''P'', ''R'', ''S'', ''U'' (and Charts ''P'' and ''N'') identify balances which use the CG Beginning Balance amount for balance forwards.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'SubFundGroupType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Create Date: The date of the initial creation of this balance record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'BalanceCreateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Year-To-Date Actual Balance: The year to date amount for an account for the given balance type. It is the beginning balance plus all transactions year-to-date.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'YearToDateActualBalance';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year Beginning Balance: The amount established on the general ledger as the beginning balance for the fiscal year.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'FiscalYearBeginningBalance';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Contracts And Grants Beginning Balance: The amount brought forward from the previous year for an open contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'ContractsAndGrantsBeginningBalance';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'July Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'JulyTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'August Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'AugustTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'September Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'SeptemberTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'October Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'OctoberTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'November Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'NovemberTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'December Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'DecemberTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'January Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'JanuaryTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'February Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'FebruaryTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'March Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'MarchTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'April Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'AprilTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'May Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'MayTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'June Transactions Total Amount: The total of transactions for an account for the month. (to-date if this is the current month)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'JuneTransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Month13 Transactions Total Amount: The total of transactions for an account for the fiscal year final period. (to-date if this is the current fiscal period)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'Month13TransactionsTotalAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DS Last Update Date: The date-time-stamp of the last update of this record. (system provided)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'GeneralLedgerProjectBalanceForAllPeriods', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
CREATE NONCLUSTERED INDEX [GLProjectBalanceForAllPeriods_YearChartBalType_IDX]
    ON [dbo].[GeneralLedgerProjectBalanceForAllPeriods]([Year] ASC, [Chart] ASC, [BalType] ASC)
    INCLUDE([Account], [Object], [FiscalYearBeginningBalance]);

