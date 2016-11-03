CREATE TABLE [dbo].[ProjectStatus] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [Status]     VARCHAR (100) NULL,
    [IsExcluded] BIT           NULL
);

