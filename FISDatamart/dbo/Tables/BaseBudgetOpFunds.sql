CREATE TABLE [dbo].[BaseBudgetOpFunds] (
    [OpFundNum] VARCHAR (6) NOT NULL,
    CONSTRAINT [PK_BaseBudgetOpFunds] PRIMARY KEY CLUSTERED ([OpFundNum] ASC)
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Op Fund Num: Op Fund Num to be displayed in pick-list.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BaseBudgetOpFunds', @level2type = N'COLUMN', @level2name = N'OpFundNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Base Budget Op Fund Numbers: A table containing the OP Funds used by the Combined Base Budget Report Op Fund select list as requested by Tom Kaiser.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'BaseBudgetOpFunds';

