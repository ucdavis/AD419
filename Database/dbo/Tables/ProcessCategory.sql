CREATE TABLE [dbo].[ProcessCategory] (
    [Id]                  INT           IDENTITY (0, 1) NOT NULL,
    [SequenceOrder]       INT           NULL,
    [Name]                VARCHAR (200) NULL,
    [IsCompleted]         BIT           NULL,
    [Notes]               VARCHAR (MAX) NULL,
    [StoredProcedureName] VARCHAR (200) NULL,
    CONSTRAINT [PK_ProcessCategory] PRIMARY KEY CLUSTERED ([Id] ASC)
);

