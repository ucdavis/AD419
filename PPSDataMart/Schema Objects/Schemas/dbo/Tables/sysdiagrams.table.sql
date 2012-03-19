CREATE TABLE [dbo].[sysdiagrams] (
    [name]         [sysname]       NOT NULL,
    [principal_id] INT             NOT NULL,
    [diagram_id]   INT             IDENTITY (1, 1) NOT FOR REPLICATION NOT NULL,
    [version]      INT             NULL,
    [definition]   VARBINARY (MAX) NULL
);

