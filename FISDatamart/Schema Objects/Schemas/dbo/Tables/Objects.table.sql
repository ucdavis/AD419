CREATE TABLE [dbo].[Objects] (
    [Year]                  INT          NOT NULL,
    [Chart]                 VARCHAR (2)  NOT NULL,
    [Object]                CHAR (4)     NOT NULL,
    [Name]                  VARCHAR (40) NULL,
    [ShortName]             CHAR (12)    NULL,
    [BudgetAggregationCode] CHAR (6)     NULL,
    [TypeCode]              CHAR (2)     NULL,
    [SubTypeCode]           CHAR (2)     NULL,
    [ActiveInd]             CHAR (1)     NULL,
    [ReportsToOPChartNum]   CHAR (2)     NULL,
    [ReportsToOPObjectNum]  CHAR (4)     NULL,
    [LevelCode]             CHAR (4)     NULL,
    [LevelActiveInd]        CHAR (1)     NULL,
    [ConsolidatnCode]       CHAR (4)     NULL,
    [RefCols]               BIT          NULL,
    [TypeName]              VARCHAR (40) NULL,
    [SubTypeName]           VARCHAR (40) NULL,
    [LevelName]             VARCHAR (40) NULL,
    [ObjectLevelShortName]  CHAR (12)    NULL,
    [ConsolidatnName]       VARCHAR (40) NULL,
    [ConsolidatnShortName]  CHAR (12)    NULL,
    [ConsolidatnActiveInd]  CHAR (1)     NULL,
    [LastUpdateDate]        DATETIME     NULL,
    [ObjectPK]              VARCHAR (11) NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Contains the attributes of and Object, including the names of the related Object Level and Object Consolidation entities.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fiscal Year: Identifies a 12 month accounting period', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Number: Identifier used to classify accounting transactions by type. Examples are academic salaries, in-state travel, Reg Fee income.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'Object';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Name: The descriptive name of the object', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'Name';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Short Name: An abbreviated descriptive name of the object', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ShortName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Budget Aggregation Name: Indicates how the budget for an object code is aggregated. The code is translated as. C = Consol(idation); L = Level; O = Object', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'BudgetAggregationCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type Code: Identifies an object code as an asset, liability, expenditure, fund balance, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'TypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Sub Type Code: Code used to group object codes for special reporting.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'SubTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Active Code: A "Y" or "N" to show whether the object is currently active (Y) or inactive (N).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ActiveInd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Op Reports To Chart Of Accounts Number: The OP Chart to which this object reports.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ReportsToOPChartNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Op Reports To Object Number: The OP Object to which this object reports.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ReportsToOPObjectNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Level Number: Indicates an object code or an object code grouping for system monitoring and special routing and approval.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'LevelCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Level Active Code: A "Y" or "N" to show whether the object is currently active (Y) or inactive (N).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'LevelActiveInd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Consolidation Number: Identifies a group of object levels and their associated object codes for budgeting and Office of the President requirements.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ConsolidatnCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Ref Cols: FISDataMart field always populated with 0/false during data download process. Usage unknown.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'RefCols';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Type Name: The descriptive name of the object type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'TypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Sub Type Name: The descriptive name of the object sub type', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'SubTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Level Name: The descriptive name of the object level', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'LevelName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Level Short Name: An abbreviated descriptive name of the object level', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ObjectLevelShortName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Consolidation Name: The descriptive name of the object level', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ConsolidatnName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Consolidation Short Name: An abbreviated descriptive name of the object level', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ConsolidatnShortName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object Consolidation Active Code: A "Y" or "N" to show whether the object is currently active (Y) or inactive (N).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ConsolidatnActiveInd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DS Last Update Date: The date-time-stamp of the last update of this record.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key:Unique identifier used for performing FK joins on other tables with this one; composed of Year, Chart, and Object.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Objects', @level2type = N'COLUMN', @level2name = N'ObjectPK';

