CREATE TABLE [dbo].[AccountType] (
    [AccountType]     CHAR (2)     NOT NULL,
    [AccountTypeName] VARCHAR (50) NULL,
    [LastUpdateDate]  DATETIME     NOT NULL,
    CONSTRAINT [PK_AccountType] PRIMARY KEY CLUSTERED ([AccountType] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial Account Types: This table lists the various account types defined in DaFIS.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AccountType';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Type Code: Identifies the account type. Examples of account types include EX (expenditure), BS (balance sheet), IN (income), UN (unbalanced), etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AccountType', @level2type = N'COLUMN', @level2name = N'AccountType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Type Name: The descriptive name of the account type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AccountType', @level2type = N'COLUMN', @level2name = N'AccountTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Last Update Date: The last time this row was updated in the FISDataMart.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'AccountType', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

