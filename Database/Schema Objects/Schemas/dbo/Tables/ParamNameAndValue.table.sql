CREATE TABLE [dbo].[ParamNameAndValue] (
    [ParamName]   VARCHAR (255)  NOT NULL,
    [ParamValue]  VARCHAR (255)  NOT NULL,
    [Description] VARCHAR (1024) NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Table Name: A table containing all of the table names or table name prefixes, midfixes or suffixes for the AD419 report tables', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ParamNameAndValue';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Table Name Variable Name: The name of the table variable name corresponding to the table name', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ParamNameAndValue', @level2type = N'COLUMN', @level2name = N'ParamName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Table Name: The name, prefix, midfix or suffix of the table', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ParamNameAndValue', @level2type = N'COLUMN', @level2name = N'ParamValue';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Description: A description of the table''s intended use', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ParamNameAndValue', @level2type = N'COLUMN', @level2name = N'Description';

