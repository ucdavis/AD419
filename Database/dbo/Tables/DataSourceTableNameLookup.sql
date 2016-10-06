CREATE TABLE [dbo].[DataSourceTableNameLookup] (
    [Id]            INT           IDENTITY (1, 1) NOT NULL,
    [DataSource]    VARCHAR (5)   NULL,
    [DataType]      VARCHAR (5)   NULL,
    [DataTableName] VARCHAR (100) NULL,
    CONSTRAINT [PK_DataSourceTableNameLookup] PRIMARY KEY CLUSTERED ([Id] ASC)
);

