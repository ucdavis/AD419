CREATE TABLE [dbo].[BaseBudgetSubFundGroups] (
    [SubFundGroupNum] VARCHAR (6) NOT NULL,
    [OpFundNum]       VARCHAR (6) NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'BaseBudgetSubFundGroups: A Table to hold all the possible types of Base Budget Sub Fund Groups, i.e. GENFND,  GENICR, ENDOW, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BaseBudgetSubFundGroups';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Num: Code that identifies the fund source of an account. Similar to the A11 system fund number, but will be an alpha abbreviation instead of a number. Examples of sub fund groups include continuing education accounts, scholarships and fellowships, general funds, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BaseBudgetSubFundGroups', @level2type = N'COLUMN', @level2name = N'SubFundGroupNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Number: UCD/OP reporting fund (optional)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BaseBudgetSubFundGroups', @level2type = N'COLUMN', @level2name = N'OpFundNum';

