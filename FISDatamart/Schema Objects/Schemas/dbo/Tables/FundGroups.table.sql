CREATE TABLE [dbo].[FundGroups] (
    [FundGroup]      CHAR (2)     NOT NULL,
    [FundGroupName]  VARCHAR (40) NULL,
    [LastUpdateDate] DATETIME     NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Fund Groups: Identifies broad categories such as Current Funds, Loan Funds, Plant Funds, etc...', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FundGroups';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fund Group Code: Code that identifies a major fund group. The fund groups are current funds, plant funds, agency funds, endowment funds, loan funds and ucrs funds.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FundGroups', @level2type = N'COLUMN', @level2name = N'FundGroup';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fund Group Name: Descriptive name for the Fund Group', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FundGroups', @level2type = N'COLUMN', @level2name = N'FundGroupName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The last time this row was updated in Decision Support.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FundGroups', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

