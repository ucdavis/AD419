CREATE TABLE [dbo].[BillingIDConversions] (
    [BillingID]           CHAR (4)      NOT NULL,
    [Chart]               VARCHAR (2)   NOT NULL,
    [Account]             CHAR (7)      NULL,
    [SubAccount]          CHAR (5)      NULL,
    [OrgID]               CHAR (4)      NULL,
    [ProjectNumTransLine] CHAR (10)     NULL,
    [EffectiveDate]       DATETIME      NULL,
    [ExpirationDate]      DATETIME      NULL,
    [Comments]            VARCHAR (120) NULL,
    [LastUpdateDate]      DATETIME      NULL,
    CONSTRAINT [PK_BillingIDConversions_1] PRIMARY KEY CLUSTERED ([BillingID] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Legacy Billing IDs; Contains information to convert from a billing id, provided in a service unit general ledger transaction, to dafis Chart/Account/Sub-Acct/Project identifiers.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Billing Id: The Id number supplied by the user to the service unit.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'BillingID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts to be used on a transaction in dafis ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'Chart';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier for a transaction used to classify financial resources for accounting and reporting purposes in dafis ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'Account';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Account Number: Organization chosen identifier for a transaction used to subdivide accounts for more detailed analysis and reporting in dafis', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'SubAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifier of an Organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'OrgID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Transaction Line Project Number: Code used on a transaction to track and accumulate transactions across multiple charts, accounts and fund groups in dafis.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'ProjectNumTransLine';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Billing Id Effective Date: The effective date of this billing id.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'EffectiveDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Billing Id Expiration Date: The expiration date of this billing id. A null value indicates that the billing id will not expire after any particular date.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'ExpirationDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Billing Id Comments: The comments provided by the user to explain the use of this billing id.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'Comments';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Billing Id Last Update Date: The last time this Billing Id information was changed.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BillingIDConversions', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

