CREATE TABLE [dbo].[ObjectSubTypes] (
    [ObjectSubType]     VARCHAR (2)  NOT NULL,
    [ObjectSubTypeName] VARCHAR (40) NULL,
    [LastUpdateDate]    DATETIME     NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Sub Type: The list of object sub-types that identify objects as needed for special reporting.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectSubTypes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Sub Type Code: Identifies an object as an asset, liability, expenditure, fund balance,', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectSubTypes', @level2type = N'COLUMN', @level2name = N'ObjectSubType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Sub Type Name: The descriptive name of the object type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectSubTypes', @level2type = N'COLUMN', @level2name = N'ObjectSubTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ObjectSubTypes', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

