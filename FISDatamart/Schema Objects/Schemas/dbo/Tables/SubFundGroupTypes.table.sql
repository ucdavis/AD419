CREATE TABLE [dbo].[SubFundGroupTypes] (
    [SubFundGroupType]               VARCHAR (2)  NOT NULL,
    [SubFundGroupTypeName]           VARCHAR (40) NULL,
    [ContractsAndGrantsFlag]         CHAR (1)     NULL,
    [SponsoredFundFlag]              CHAR (1)     NULL,
    [FederalFundsFlag]               CHAR (1)     NULL,
    [GiftFundsFlag]                  CHAR (1)     NULL,
    [AwardOwnershipCodeRequiredFlag] CHAR (1)     NULL,
    [FundEndDateRequiredFlag]        CHAR (1)     NULL,
    [PaymentMediumCodeRequiredFlag]  CHAR (1)     NULL,
    [CostTransferRequiredFlag]       CHAR (1)     NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Sub Fund Group Types', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Type Code: Used to group like sub funds. For example, Federal Contracts would be a sub fund group type with a number of associated sub fund groups.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'SubFundGroupType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Type Name: Descriptive name for the Sub Fund Group Type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'SubFundGroupTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Contracts and Grants Flag: Whether this Sub Fund Group Type represents contracts and grants funds.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'ContractsAndGrantsFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sponsored Fund Flag:', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'SponsoredFundFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Federal Funds Flag: Whether this Sub Fund Group Type represents federal funds.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'FederalFundsFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Gift Funds Flag: Whether this Sub Fund Group Type represents gift/donation funds.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'GiftFundsFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Ownership Code Required Flag: Whether OP Funds in this Sub Fund Group Type require an award ownership code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'AwardOwnershipCodeRequiredFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fund End Date Required Flag: Whether OP Funds in this Sub Fund Group Type require an award end date.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'FundEndDateRequiredFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Payment Medium Code Required Flag: Whether OP Funds in this Sub Fund Group Type require a payment medium code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'PaymentMediumCodeRequiredFlag';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Cost Transfer Required Flag: Whether OP Funds in this Sub Fund Group Type require a cost transfer .', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroupTypes', @level2type = N'COLUMN', @level2name = N'CostTransferRequiredFlag';

