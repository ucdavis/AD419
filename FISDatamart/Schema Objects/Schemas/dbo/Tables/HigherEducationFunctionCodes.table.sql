CREATE TABLE [dbo].[HigherEducationFunctionCodes] (
    [HigherEducationFunctionCode] VARCHAR (4)  NOT NULL,
    [HigherEducationFunctionName] VARCHAR (40) NULL,
    [LastUpdateDate]              DATETIME     NULL,
    CONSTRAINT [PK_HigherEducationFunctionCode] PRIMARY KEY CLUSTERED ([HigherEducationFunctionCode] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Higher Education Function Code: This table contains Higher Education Function Codes as defined in DaFIS.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'HigherEducationFunctionCodes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Higher Education Function Code: Function codes which are assigned to each account which match expenditures to the functionality of the account. Higher Education examples are instruction, academic support, art and museums, etc. These names are the most detailed level of functional classification and are utilized in determining AICPA function codes, and federal function codes for indirect cost purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'HigherEducationFunctionCodes', @level2type = N'COLUMN', @level2name = N'HigherEducationFunctionCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Higher Education Function Name: The descriptive name of the Higher Education Function Code ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'HigherEducationFunctionCodes', @level2type = N'COLUMN', @level2name = N'HigherEducationFunctionName';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The last time this row was updated in Decision Support.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'HigherEducationFunctionCodes', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

