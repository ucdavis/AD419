CREATE TABLE [dbo].[SubAccounts] (
    [Year]           INT           NOT NULL,
    [Period]         CHAR (2)      NOT NULL,
    [Chart]          VARCHAR (2)   NOT NULL,
    [Account]        CHAR (7)      NOT NULL,
    [SubAccount]     CHAR (5)      NOT NULL,
    [SubAccountName] VARCHAR (40)  NULL,
    [ActiveInd]      CHAR (1)      NULL,
    [LastUpdateDate] SMALLDATETIME NULL,
    [SubAccountPK]   VARCHAR (23)  NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial Sub Account Reference Data: Contains the attributes specific to a Sub-Account', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Record Effective Fiscal Year: The fiscal year in which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Record Effective Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'Account';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Number: Allows an account to be broken down in more detail (Cost Center) in order to better track detailed transactions. The sub account takes on the attributes of the account it reports to, including account manager, fund group and function code. Assigned by account managers.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'SubAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Name: The descriptive name of the sub account', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'SubAccountName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Active Indicator: A "Y" or "N" to show whether the sub account is currently active (Y) or inactive (N).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'ActiveInd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key: Unique identifier used for performing FK joins with other tables comprised of Year, Period, CHart, Account, SubAccount.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubAccounts', @level2type = N'COLUMN', @level2name = N'SubAccountPK';

