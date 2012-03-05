CREATE TABLE [dbo].[ObjectTypes] (
    [ObjectType]     VARCHAR (2)  NOT NULL,
    [ObjectTypeName] VARCHAR (40) NULL,
    [LastUpdateDate] DATETIME     NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type: The list of object types that identify objects as assets, liabilities, expenditures, etc...', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectTypes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type: Identifies an object code as an asset, liability, expenditure, fund balance, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectTypes', @level2type = N'COLUMN', @level2name = N'ObjectType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type Name: The descriptive name of the object type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectTypes', @level2type = N'COLUMN', @level2name = N'ObjectTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date-time-stamp of the last update of this record in Decision Support.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectTypes', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

