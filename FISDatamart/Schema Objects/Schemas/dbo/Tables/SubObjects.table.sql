CREATE TABLE [dbo].[SubObjects] (
    [Year]           INT          NOT NULL,
    [Period]         CHAR (2)     NOT NULL,
    [Chart]          VARCHAR (2)  NOT NULL,
    [Account]        CHAR (7)     NOT NULL,
    [Object]         CHAR (4)     NOT NULL,
    [SubObject]      VARCHAR (5)  NOT NULL,
    [Name]           VARCHAR (40) NULL,
    [ShortName]      CHAR (12)    NULL,
    [ActiveInd]      CHAR (1)     NULL,
    [LastUpdateDate] DATETIME     NULL,
    [SubObjectPK]    VARCHAR (28) NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Financial Sub Object Reference Data: Contains the attributes specific to a Sub-Object created by an organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year: Identifies a 12 month accounting period', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Record Effective Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'Account';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Number: Identifier used to classify accounting transactions by type. Examples are academic salaries, in-state travel, Reg Fee income.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'Object';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Number: Provides for an object code to be broken down into greater detail. Assigned by account managers.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'SubObject';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Name: The descriptive name of the sub object', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Short Name: An abbreviated descriptive name of the sub object', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'ShortName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Object Active Indicator: A "Y" or "N" to show whether the sub object is currently active (Y) or inactive (N).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'ActiveInd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key: Unique identifier used from performing FK joins to other tables comprised of Year, Period, Chart, Account, Object, and SubObject.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'SubObjects', @level2type = N'COLUMN', @level2name = N'SubObjectPK';

