CREATE TABLE [dbo].[ProcessStatus] (
    [Id]                      INT           IDENTITY (-1, 1) NOT NULL,
    [SequenceOrder]           INT           NULL,
    [Name]                    VARCHAR (100) NULL,
    [IsCompleted]             BIT           NULL,
    [CategoryId]              INT           NULL,
    [Notes]                   VARCHAR (MAX) NULL,
    [CompletePriorToCategory] INT           NULL,
    [NoProcessingRequired]    BIT           NULL,
    [Hyperlink]               VARCHAR (100) NULL,
    CONSTRAINT [PK_ProcessStatus] PRIMARY KEY CLUSTERED ([Id] ASC)
);

