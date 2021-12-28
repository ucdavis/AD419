CREATE TABLE [dbo].[FunctionCode] (
    [FunctionCodeID] SMALLINT     NOT NULL,
    [FunctionCode]   CHAR (2)     NULL,
    [Description]    VARCHAR (50) NULL,
    CONSTRAINT [PK_FunctionCode] PRIMARY KEY CLUSTERED ([FunctionCodeID] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Base Budget Function Codes: Reference table containing lookup information for resolving Base Budget Function Type Codes for Cooperative Extension (CE), Organized Research (OR), Instruction (IR), and Other/Unknown (OT).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FunctionCode';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Function Code ID: Surrogate ID used as table''s primary key.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FunctionCode', @level2type = N'COLUMN', @level2name = N'FunctionCodeID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Base Budget Function Type Code: Used for organizing appropriations into the following categories for Base Budget reporting purposes: Cooperative Extension (CE), Organized Research (OR), Instruction (IR), and Other/Unknown (OT).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FunctionCode', @level2type = N'COLUMN', @level2name = N'FunctionCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Description: The descriptive name of what the code represents.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'FunctionCode', @level2type = N'COLUMN', @level2name = N'Description';

