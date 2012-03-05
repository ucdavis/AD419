CREATE TABLE [dbo].[SubFundGroups] (
    [Year]                        INT          NOT NULL,
    [Period]                      VARCHAR (2)  NOT NULL,
    [SubFundGroupNum]             VARCHAR (6)  NOT NULL,
    [SubFundGroupName]            VARCHAR (40) NULL,
    [FundGroupCode]               CHAR (2)     NULL,
    [SubFundGroupType]            CHAR (2)     NULL,
    [SubFundGroupActiveIndicator] CHAR (1)     NULL,
    [LastUpdateDate]              DATETIME     NULL,
    [SubFundGroupRestrictionCode] CHAR (1)     NULL,
    [OPUnexpendedBalanceAccount]  VARCHAR (7)  NULL,
    [OPFundGroup]                 VARCHAR (6)  NULL,
    [OPOverheadClearingAccount]   VARCHAR (6)  NULL,
    [SubFundGroupPK]              VARCHAR (14) NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Sub Fund Groups', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Record Effective Fiscal Year: The fiscal year in which this set of values was in effect.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Record Effective Period: The fiscal period in which this set of values was in effect.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Number: Code that identifies the fund source of an account. Similar to the A11 system fund number, but will be an alpha abbreviation instead of a number. Examples of sub fund groups include continuing education accounts, scholarships and fellowships, general funds, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Description (Name):', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fund Group Code: Code that identifies a major fund group. The fund groups are current funds, plant funds, agency funds, endowment funds, loan funds and ucrs funds.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'FundGroupCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Type Code: Used to group like sub funds. For example, Federal Contracts would be a sub fund group type with a number of associated sub fund groups.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Active Indicator: Indicates whether this Sub Fund Group may be attached to an account.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupActiveIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The last time this row was updated in Decision Support.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Restriction Code: Defines whether the funds in this sub fund group are restricted or unrestricted.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupRestrictionCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Unexpended Balance Account: The unexpended balance account these funds should be reappropriated to at the end of the year.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'OPUnexpendedBalanceAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Group: The OP designated fund group that this sub fund group reports to.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'OPFundGroup';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Overhead Clearing Account: The OP clearing account for charging overhead (Indirect Costs).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'OPOverheadClearingAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Primary Key: Unique identifier composed of Year, Period and SubFundGroupNum.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupPK';

