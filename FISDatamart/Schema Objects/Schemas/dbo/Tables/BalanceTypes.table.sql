CREATE TABLE [dbo].[BalanceTypes] (
    [BalanceTypeCode]          CHAR (2)     NOT NULL,
    [BalanceTypeName]          VARCHAR (40) NULL,
    [BalanceCategoryCode]      VARCHAR (2)  NULL,
    [BalanceCategoryName]      VARCHAR (40) NULL,
    [BalanceReportingTypeCode] CHAR (2)     NULL,
    [LastUpdateDate]           DATETIME     NOT NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Identifies the types of reporting to which given values of Balance type belong.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BalanceTypes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Code: Designates the type of balance to which a given transaction is summarized in the General Ledger Balance tables.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BalanceTypes', @level2type = N'COLUMN', @level2name = N'BalanceTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Type Name: Descriptive name of the balance type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BalanceTypes', @level2type = N'COLUMN', @level2name = N'BalanceTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Category Name: Descriptive name of the reporting category of the balance type code: either "Appropriations", "Encumbrances", "Expenditures", or "FTE"', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BalanceTypes', @level2type = N'COLUMN', @level2name = N'BalanceCategoryName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Balance Reporting Type: Code for the type of report for which this type of balance would be appropriate: "AC" identifies balance types for income statement (revenue, expenditures, and current balances) usage.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BalanceTypes', @level2type = N'COLUMN', @level2name = N'BalanceReportingTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BalanceTypes', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

